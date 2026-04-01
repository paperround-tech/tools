#!/usr/bin/env npx tsx

import { SSMClient, GetParameterCommand } from "@aws-sdk/client-ssm";
import * as mysql from "mysql2/promise";
import { existsSync, readFileSync } from "fs";
import { execSync } from "child_process";

const REGION = "eu-west-1";
const PARAM_NAME = "/appconfig/live";

interface DbConfig {
  host: string;
  user: string;
  password: string;
  database: string;
  port: number;
}

function decodePassword(escaped: string): string {
  // Handle $$ -> $ escaping in INI files
  let decoded = escaped.replace(/\$\$/g, "$");
  // Handle URL-encoded characters like %xx
  try {
    decoded = decodeURIComponent(decoded.replace(/#x([0-9a-fA-F]{2})/g, "%$1"));
  } catch {
    // If decoding fails, use as-is
  }
  return decoded;
}

async function getDbConfig(): Promise<DbConfig> {
  // Check for local tunnel override (e.g., via bastion)
  const useLocalTunnel = process.env.DB_USE_TUNNEL === "1";
  const tunnelPort = parseInt(process.env.DB_TUNNEL_PORT || "3306");
  
  const ssm = new SSMClient({ region: REGION });
  
  const command = new GetParameterCommand({
    Name: PARAM_NAME,
    WithDecryption: true,
  });
  
  const response = await ssm.send(command);
  const configText = response.Parameter?.Value || "";
  
  // Parse INI-style config
  const lines = configText.split("\n");
  let host = "";
  let user = "";
  let password = "";
  
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith("readonlydb =")) {
      host = trimmed.split("=")[1].trim();
    } else if (trimmed.startsWith("update_user_escaped")) {
      // Use write user (safe on replica, readonly user has IP restrictions)
      const userPass = trimmed.split("=")[1].trim();
      const colonIdx = userPass.indexOf(":");
      user = userPass.substring(0, colonIdx);
      password = userPass.substring(colonIdx + 1);
    }
  }
  
  return {
    host: useLocalTunnel ? "127.0.0.1" : host,
    user,
    password,
    database: "hnddb",
    port: useLocalTunnel ? tunnelPort : 3306,
  };
}

async function runQuery(sql: string): Promise<void> {
  const config = await getDbConfig();
  
  const connection = await mysql.createConnection({
    host: config.host,
    user: config.user,
    password: config.password,
    database: config.database,
    port: config.port,
  });
  
  try {
    const [rows, fields] = await connection.execute(sql);
    
    if (Array.isArray(rows) && rows.length > 0) {
      // Print column headers
      if (fields && Array.isArray(fields)) {
        const headers = fields.map((f: any) => f.name);
        console.log(headers.join("\t"));
        console.log(headers.map(() => "---").join("\t"));
      }
      
      // Print rows
      for (const row of rows as any[]) {
        const values = Object.values(row).map(v => 
          v === null ? "NULL" : String(v)
        );
        console.log(values.join("\t"));
      }
      
      console.log(`\n(${(rows as any[]).length} rows)`);
    } else {
      console.log("Query executed successfully. No rows returned.");
    }
  } finally {
    await connection.end();
  }
}

function checkVpnConnection(): void {
  if (process.env.DB_USE_TUNNEL === "1" || process.env.SKIP_VPN_CHECK === "1") return;

  const pidFile = "/tmp/ppr-vpn.pid";
  try {
    if (existsSync(pidFile)) {
      const pid = readFileSync(pidFile, "utf-8").trim();
      if (pid) {
        execSync(`ps -p ${pid}`, { stdio: "ignore" });
        return;
      }
    }
  } catch {
    // Process not running or file not readable
  }

  console.warn("\u26a0  No live VPN connection detected. Query may fail.");
  console.warn("   To connect: npx tsx openvpn/vpn.ts connect live");
  console.warn("");
}

// Main
const sql = process.argv.slice(2).join(" ");

if (!sql) {
  console.error("Usage: ./query-db.ts <SQL query>");
  console.error('Example: ./query-db.ts "SELECT * FROM shops LIMIT 5"');
  process.exit(1);
}

checkVpnConnection();

runQuery(sql)
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Error:", err.message);
    process.exit(1);
  });
