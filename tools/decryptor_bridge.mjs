#!/usr/bin/env node
/**
 * Decryptor Bridge for Freedom Config Collector v2
 * Decrypts encrypted container files (.ehi, .npvt, .npvs, .hat, .nm, .dark, .ssc, .hc, etc.)
 * using direct functions from cf_decryptor_bot with full expiration detection.
 */

import { processFileDecryption, checkExpiration, extractXrayLinks } from '../reference/free-config/worker/cf_decryptor_bot';
import fs from 'node:fs';
import path from 'node:path';

async function processDirectory(dirPath) {
    if (!fs.existsSync(dirPath)) {
        console.error(JSON.stringify({ ok: false, error: "Directory not found: " + dirPath }));
        process.exit(1);
    }

    const files = fs.readdirSync(dirPath);
    const results = [];
    let totalContainers = 0;
    let successDecrypted = 0;
    let hasExpiryCount = 0;
    let expiredCount = 0;

    const encryptedExts = [
        '.ehi', '.npvt', '.npvs', '.inpv', '.hat', '.nm',
        '.dark', '.darktunnel', '.ssc', '.hc', '.slip'
    ];

    for (const filename of files) {
        const fullPath = path.join(dirPath, filename);
        try {
            if (!fs.statSync(fullPath).isFile()) continue;
        } catch {
            continue;
        }

        const ext = path.extname(filename).toLowerCase();
        if (!encryptedExts.includes(ext)) continue;

        totalContainers++;

        try {
            const fileBuf = fs.readFileSync(fullPath);
            const decResult = await processFileDecryption(new Uint8Array(fileBuf), filename, '');
            if (!decResult) continue;

            successDecrypted++;
            const exp = checkExpiration(decResult);
            if (exp.hasExpiry) {
                hasExpiryCount++;
                if (exp.isExpired) {
                    expiredCount++;
                }
            }

            const rawProfiles = decResult.profiles || (Array.isArray(decResult.parsed) ? decResult.parsed : decResult.parsed?.configs || []);
            const xrayLinks = extractXrayLinks ? extractXrayLinks(rawProfiles) : [];

            results.push({
                file: filename,
                hasExpiry: exp.hasExpiry || false,
                isExpired: exp.isExpired || false,
                expiryDate: exp.formatted || '',
                expiryTimestamp: exp.expireDate ? exp.expireDate.getTime() : 0,
                links: xrayLinks.map(l => ({
                    name: l.name || filename,
                    protocol: l.protocol || 'unknown',
                    link: l.link || ''
                })),
                profiles: rawProfiles
            });
        } catch (e) {
            // Container was locked with user password or unsupported format
        }
    }

    const outputPayload = JSON.stringify({
        ok: true,
        stats: {
            totalContainers,
            successDecrypted,
            hasExpiryCount,
            expiredCount
        },
        results
    });

    const outputFile = process.argv[3];
    if (outputFile) {
        fs.mkdirSync(path.dirname(outputFile), { recursive: true });
        fs.writeFileSync(outputFile, outputPayload, 'utf-8');
        console.log(JSON.stringify({ ok: true, stats: { totalContainers, successDecrypted, hasExpiryCount, expiredCount }, writtenTo: outputFile }));
    } else {
        console.log(outputPayload);
    }
}

const targetDir = process.argv[2] || 'G:/Ai project/10Dream/decryptor/file for test';
processDirectory(targetDir);
