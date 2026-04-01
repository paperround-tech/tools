#!/usr/bin/env npx tsx

import { readFileSync, writeFileSync, existsSync, unlinkSync } from "fs";
import { execSync, spawnSync, spawn } from "child_process";
import { resolve, dirname } from "path";

// ─── Paths ──────────────────────────────────────────────────────────────────

const SCRIPT_DIR = dirname(resolve(__filename));
const CONFIG_PATH = resolve(SCRIPT_DIR, "..", "config.json");
const PID_FILE = "/tmp/ppr-vpn.pid";
const LOG_FILE = "/tmp/ppr-vpn.log";
const INFO_FILE = "/tmp/ppr-vpn.info";

// ─── Types ──────────────────────────────────────────────────────────────────

interface Profile {
  name: string;
  path: string;
}

interface Environment {
  profiles: Profile[];
}

interface VpnConfig {
  openvpn_bin: string;
  connect_timeout: number;
  ssm_password_path: string;
  environments: Record<string, Environment>;
}

// ─── Config ─────────────────────────────────────────────────────────────────

function loadConfig(): VpnConfig {
  if (!existsSync(CONFIG_PATH)) {
    console.error(`ERROR: Config not found at ${CONFIG_PATH}`);
    console.error("Copy config.example.json to config.json and edit it.");
    process.exit(1);
  }
  const raw = JSON.parse(readFileSync(CONFIG_PATH, "utf-8"));
  return raw.openvpn as VpnConfig;
}

// ─── State Helpers ──────────────────────────────────────────────────────────

function isConnected(): boolean {
  if (!existsSync(PID_FILE)) return false;
  const pid = readFileSync(PID_FILE, "utf-8").trim();
  if (!pid) return false;
  try {
    execSync(`ps -p ${pid}`, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function cleanupFiles(): void {
  for (const f of [PID_FILE, INFO_FILE, LOG_FILE]) {
    try { unlinkSync(f); } catch {}
  }
}

// ─── Commands ───────────────────────────────────────────────────────────────

async function connect(envName: string): Promise<void> {
  const config = loadConfig();

  if (isConnected()) {
    const info = safeRead(INFO_FILE);
    const current = info.split(":")[0];
    console.error(`Already connected to '${current}'. Disconnect first: vpn disconnect`);
    process.exit(1);
  }

  const env = config.environments[envName];
  if (!env) {
    console.error(`ERROR: Unknown environment '${envName}'`);
    console.error(`Available: ${Object.keys(config.environments).join(", ")}`);
    process.exit(1);
  }

  const openvpnBin = config.openvpn_bin || "/opt/homebrew/opt/openvpn/sbin/openvpn";
  const connectTimeout = config.connect_timeout || 15;
  const ssmPath = config.ssm_password_path;

  if (!existsSync(openvpnBin)) {
    console.error(`ERROR: OpenVPN binary not found at ${openvpnBin}`);
    console.error("Install with: brew install openvpn");
    process.exit(1);
  }

  if (!ssmPath) {
    console.error("ERROR: ssm_password_path not set in config");
    process.exit(1);
  }

  // Fetch password from SSM (eu-west-1)
  console.log("Fetching credentials from SSM...");
  let password: string;
  try {
    password = execSync(
      `AWS_PAGER="" aws ssm get-parameter --name "${ssmPath}" --with-decryption --query 'Parameter.Value' --output text --region eu-west-1`,
      { encoding: "utf-8", stdio: ["pipe", "pipe", "pipe"] }
    ).trim();
  } catch {
    console.error(`ERROR: Failed to fetch password from SSM (${ssmPath})`);
    console.error("Ensure you're logged in: aws sso login --profile paperround");
    process.exit(1);
  }

  if (!password) {
    console.error(`ERROR: Empty password returned from SSM (${ssmPath})`);
    process.exit(1);
  }

  // Try each profile in order
  for (const profile of env.profiles) {
    if (!existsSync(profile.path)) {
      console.log(`⚠  Profile not found: ${profile.path} (skipping ${profile.name})`);
      continue;
    }

    // Extract username from .ovpn header
    const ovpnContent = readFileSync(profile.path, "utf-8");
    const usernameMatch = ovpnContent.match(/OVPN_ACCESS_SERVER_USERNAME=(.+)/);
    if (!usernameMatch) {
      console.log(`⚠  No username found in profile (skipping ${profile.name})`);
      continue;
    }
    const username = usernameMatch[1].trim();

    console.log(`→ Trying ${envName}/${profile.name}...`);

    // Pre-create log and PID files as current user
    writeFileSync(LOG_FILE, "");
    writeFileSync(PID_FILE, "");

    // Create auth FIFO — credentials pass through a pipe, never touch disk
    const authFifo = `/tmp/vpn-auth-${Date.now()}`;
    execSync(`mkfifo -m 600 "${authFifo}"`);

    // Write credentials to FIFO in background (blocks until reader opens it)
    const writer = spawn("sh", ["-c", `printf '%s\\n%s\\n' '${username.replace(/'/g, "'\\''")}' '${password.replace(/'/g, "'\\''")}' > "${authFifo}"`], {
      stdio: "ignore",
      detached: true,
    });
    writer.unref();

    // Start openvpn daemon
    let exitCode: number;
    try {
      execSync(
        `sudo "${openvpnBin}" ` +
        `--config "${profile.path}" ` +
        `--auth-user-pass "${authFifo}" ` +
        `--auth-nocache ` +
        `--auth-retry none ` +
        `--connect-retry-max 1 ` +
        `--daemon ppr-vpn ` +
        `--log-append "${LOG_FILE}" ` +
        `--writepid "${PID_FILE}" ` +
        `--verb 3`,
        { stdio: "inherit" }
      );
      exitCode = 0;
    } catch {
      exitCode = 1;
    }

    // Clean up FIFO
    try { unlinkSync(authFifo); } catch {}

    if (exitCode !== 0) {
      console.log("  ✗ OpenVPN failed to start");
      continue;
    }

    // Wait for connection or timeout
    let connected = false;
    for (let t = 0; t < connectTimeout; t++) {
      try {
        const log = readFileSync(LOG_FILE, "utf-8");
        if (log.includes("Initialization Sequence Completed")) {
          connected = true;
          break;
        }
      } catch {}

      // Check if process died early
      const pid = safeRead(PID_FILE);
      if (pid) {
        try {
          execSync(`ps -p ${pid}`, { stdio: "ignore" });
        } catch {
          break; // Process died
        }
      }

      await sleep(1000);
    }

    if (connected) {
      writeFileSync(INFO_FILE, `${envName}:${profile.name}`);
      console.log(`  ✓ Connected to ${envName} via ${profile.name}`);
      return;
    }

    console.log(`  ✗ Timed out after ${connectTimeout}s`);

    // Kill failed attempt
    const pid = safeRead(PID_FILE);
    if (pid) {
      try { execSync(`sudo kill ${pid}`, { stdio: "ignore" }); } catch {}
    }
    writeFileSync(LOG_FILE, "");
    writeFileSync(PID_FILE, "");
  }

  console.error(`ERROR: All ${env.profiles.length} profile(s) failed for '${envName}'`);
  process.exit(1);
}

function disconnect(): void {
  // Check for tracked connection first, then orphaned processes
  const pid = safeRead(PID_FILE);
  const orphanPid = findOrphanedProcess();
  const targetPid = (pid && isProcessRunning(pid)) ? pid : orphanPid;

  if (!targetPid) {
    cleanupFiles();
    console.log("No active VPN connection");
    return;
  }

  const info = safeRead(INFO_FILE) || `unknown (PID: ${targetPid})`;

  // Use spawnSync for proper TTY passthrough on sudo prompts
  const killResult = spawnSync("sudo", ["kill", targetPid], { stdio: "inherit" });

  if (killResult.status !== 0) {
    console.error(`sudo kill exited with status ${killResult.status}`);
    if (isProcessRunning(targetPid)) {
      console.error(`Process still running. Run manually: sudo kill ${targetPid}`);
      return;
    }
  }

  // Give the process a moment to exit
  for (let i = 0; i < 5; i++) {
    if (!isProcessRunning(targetPid)) break;
    spawnSync("sleep", ["0.5"]);
  }

  if (isProcessRunning(targetPid)) {
    console.error(`OpenVPN process still running (PID: ${targetPid}). Files left intact.`);
    return;
  }

  cleanupFiles();
  console.log(`Disconnected from ${info}`);
}

function status(): void {
  if (isConnected()) {
    const info = safeRead(INFO_FILE);
    const [env, profile] = info.split(":");
    const pid = safeRead(PID_FILE);
    console.log(`Connected: ${env}/${profile} (PID: ${pid})`);
  } else {
    // Check for orphaned openvpn processes
    const orphanPid = findOrphanedProcess();
    if (orphanPid) {
      console.log(`Orphaned openvpn process detected (PID: ${orphanPid})`);
      console.log("Run 'vpn disconnect' to stop it.");
    } else {
      cleanupFiles();
      console.log("Not connected");
    }
  }
}

function list(): void {
  const config = loadConfig();
  console.log("Environments:");
  for (const [name, env] of Object.entries(config.environments)) {
    const profileNames = env.profiles.map((p) => p.name).join(", ");
    console.log(`  ${name}: ${profileNames}`);
  }
}

function help(): void {
  console.log(`PPR OpenVPN Tool

Commands:
    vpn connect <env>   Connect to an environment (auto-failover)
    vpn disconnect      Disconnect the active VPN
    vpn status          Show current connection status
    vpn list            List environments and profiles
    vpn help            Show this help

Examples:
    vpn connect live    # Connect to live (tries primary, backup, backup2)
    vpn connect test    # Connect to test
    vpn status          # Check connection
    vpn disconnect      # Disconnect`);
}

// ─── Utilities ──────────────────────────────────────────────────────────────

function safeRead(path: string): string {
  try { return readFileSync(path, "utf-8").trim(); } catch { return ""; }
}

function isProcessRunning(pid: string): boolean {
  try {
    execSync(`ps -p ${pid}`, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function findOrphanedProcess(): string | null {
  try {
    const output = execSync("pgrep -f 'openvpn.*--daemon ppr-vpn'", { encoding: "utf-8" }).trim();
    return output.split("\n")[0] || null;
  } catch {
    return null;
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ─── Main ───────────────────────────────────────────────────────────────────

const [cmd, ...args] = process.argv.slice(2);

switch (cmd) {
  case "connect":
    if (!args[0]) {
      const config = loadConfig();
      console.error("Usage: vpn connect <environment>");
      console.error(`Available: ${Object.keys(config.environments).join(", ")}`);
      process.exit(1);
    }
    connect(args[0]).catch((err) => {
      console.error("Error:", err.message);
      process.exit(1);
    });
    break;
  case "disconnect":
    disconnect();
    break;
  case "status":
    status();
    break;
  case "list":
    list();
    break;
  case "help":
  case undefined:
    help();
    break;
  default:
    console.error(`Unknown command: ${cmd}`);
    help();
    process.exit(1);
}
