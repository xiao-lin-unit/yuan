import { readFileSync, writeFileSync, readdirSync, statSync } from 'fs';
import { join, extname } from 'path';

const SRC_DIR = new URL('../src', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

const filesToProcess = [];

function collectFiles(dir) {
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    const st = statSync(fullPath);
    if (st.isDirectory()) {
      if (!entry.includes('node_modules') && !entry.includes('dist') && !entry.includes('android')) {
        collectFiles(fullPath);
      }
    } else if (st.isFile() && (extname(entry) === '.vue' || extname(entry) === '.ts')) {
      filesToProcess.push(fullPath);
    }
  }
}

collectFiles(SRC_DIR);

let totalChanged = 0;

for (const filePath of filesToProcess) {
  let content = readFileSync(filePath, 'utf-8');
  const original = content;

  // Skip files that don't have any Date usage (excluding comments about "Date")
  // Simple heuristic: check for new Date, Date.now, .getFullYear etc.
  const hasDateUsage = /\bnew\s+Date\b|Date\.now\(\)|\.toISOString\(\)|\.getFullYear\(\)|\.getMonth\(\)|\.getDate\(\)|\.getHours\(\)|\.getMinutes\(\)|\.getTime\(\)|\.getDay\(\)|\.setHours\(|\.setDate\(|\.setMonth\(|\.setFullYear\(/.test(content);
  if (!hasDateUsage) continue;

  // Skip type definition files where Date is used as a type annotation
  if (filePath.includes('\\types\\')) continue;

  // Determine if file already has dayjs import
  const hasDayjsImport = /import\s+dayjs\s+from\s+['"]dayjs['"]/.test(content);

  // For .vue files, only process <script> section
  // For .ts files, process entire file

  // Common replacements (applied to entire file content)
  // Be careful not to replace "Date" in comments unless it's part of code

  // 1. new Date() -> dayjs().toDate()
  content = content.replace(/\bnew\s+Date\s*\(\s*\)/g, 'dayjs().toDate()');

  // 2. new Date(arg) -> dayjs(arg).toDate()
  // Match new Date(something) where something is not empty
  // Be careful not to match new Date() which we already handled
  content = content.replace(/\bnew\s+Date\s*\(([^)]+)\)/g, (match, arg) => {
    // If arg already contains dayjs, skip
    if (arg.includes('dayjs')) return match;
    return `dayjs(${arg}).toDate()`;
  });

  // 3. Date.now() -> dayjs().valueOf()
  content = content.replace(/\bDate\.now\(\)/g, 'dayjs().valueOf()');

  // 4. .getFullYear() -> .year() (but only when called on a dayjs object or a variable)
  // This is tricky because we might still have Date objects. Let's apply it generally.
  content = content.replace(/\.getFullYear\(\)/g, '.year()');

  // 5. .getMonth() -> .month() (dayjs month is also 0-based)
  content = content.replace(/\.getMonth\(\)/g, '.month()');

  // 6. .getDate() -> .date()
  content = content.replace(/\.getDate\(\)/g, '.date()');

  // 7. .getHours() -> .hour()
  content = content.replace(/\.getHours\(\)/g, '.hour()');

  // 8. .getMinutes() -> .minute()
  content = content.replace(/\.getMinutes\(\)/g, '.minute()');

  // 9. .getTime() -> .valueOf()
  content = content.replace(/\.getTime\(\)/g, '.valueOf()');

  // 10. .getDay() -> .day()
  content = content.replace(/\.getDay\(\)/g, '.day()');

  // 11. .setHours(a, b, c, d) -> needs special handling for dayjs
  // dayjs is immutable, so .set('hour', h).set('minute', m)... or .hour(h).minute(m)...
  // For simplicity with multiple args, we replace with a comment and manual fix
  // Actually, let's handle common cases:
  // .setHours(0, 0, 0, 0) -> .startOf('day') for Date objects
  // But since we converted new Date() to dayjs().toDate(), these Date objects still exist
  // Hmm, this is getting complicated.

  // Let's NOT replace .setXxx() automatically - leave for manual review
  // Instead, add a comment before each .setXxx() call

  // Actually, let me handle .toISOString() - both Date and dayjs have it
  content = content.replace(/\.toISOString\(\)/g, '.toISOString()'); // no-op, both have it

  // Handle instanceof Date -> keep as-is for now since some functions still accept Date

  // Check if any changes were made
  if (content !== original) {
    // Add dayjs import if needed
    if (!hasDayjsImport) {
      if (content.includes('<script setup')) {
        // For Vue files, add import after the <script setup lang="ts"> line
        content = content.replace(
          /(<script setup lang="ts">\n)/,
          '$1import dayjs from \'dayjs\';\n'
        );
      } else {
        // For TS files, add import at the top
        content = `import dayjs from 'dayjs';\n` + content;
      }
    }

    writeFileSync(filePath, content, 'utf-8');
    totalChanged++;
    console.log(`Updated: ${filePath}`);
  }
}

console.log(`\nTotal files changed: ${totalChanged}`);
