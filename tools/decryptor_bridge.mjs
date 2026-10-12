#!/usr/bin/env node
/**
 * Decryptor Bridge for Freedom Config Collector v2
 * Decrypts encrypted container files (.ehi, .npvt, .hat, .nm, etc.) using cf_decryptor_bot
 */

import bot from '../reference/free-config/worker/cf_decryptor_bot';
import fs from 'node:fs';
import path from 'node:path';

async function processDirectory(dirPath) {
    if (!fs.existsSync(dirPath)) {
        console.error(JSON.stringify({ error: "Directory not found: " + dirPath }));
        process.exit(1);
    }

    const files = fs.readdirSync(dirPath);
    const results = [];

    for (const filename of files) {
        const fullPath = path.join(dirPath, filename);
        if (!fs.statSync(fullPath).isFile()) continue;

        const ext = path.extname(filename).toLowerCase();
        // Check if file is an encrypted container
        const encryptedExts = ['.ehi', '.npvt', '.npvs', '.inpv', '.hat', '.nm', '.dark', '.darktunnel', '.ssc', '.hc', '.slip'];
        if (!encryptedExts.includes(ext)) continue;

        try {
            const fileBuf = fs.readFileSync(fullPath);
            const fd = new FormData();
            const blob = new Blob([fileBuf]);
            fd.append('files', blob, filename);
            fd.append('format', 'mihomo');

            const req = new Request('https://worker.local/api/decrypt', { method: 'POST', body: fd });
            const res = await bot.fetch(req, {}, {});
            const json = await res.json();

            if (json.ok && json.profiles && json.profiles.length > 0) {
                // Check if any expiry exists
                let isExpired = false;
                let expiryTimestamp = 0;
                for (const p of json.profiles) {
                    const exp = p.configExpiryTimestamp || p.expiryDate || p.expiresAt || p.expiryTime;
                    if (exp) {
                        const ts = Number(exp);
                        if (ts > 0) {
                            expiryTimestamp = ts < 1e11 ? ts * 1000 : ts;
                            if (expiryTimestamp < Date.now()) {
                                isExpired = true;
                            }
                        }
                    }
                }

                results.push({
                    file: filename,
                    profiles: json.profiles,
                    isExpired: isExpired,
                    expiryTimestamp: expiryTimestamp
                });
            }
        } catch (e) {
            // file was locked or failed
        }
    }

    console.log(JSON.stringify({ ok: true, results }));
}

const targetDir = process.argv[2] || 'G:/Ai project/10Dream/decryptor/file for test';
processDirectory(targetDir);
