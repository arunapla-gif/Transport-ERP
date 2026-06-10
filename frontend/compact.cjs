const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, 'src', 'pages', 'GcEntry.jsx');
let content = fs.readFileSync(file, 'utf8');

content = content.replace(/h-11/g, 'h-9');
content = content.replace(/rounded-2xl p-5/g, 'rounded-xl p-3');
content = content.replace(/gap-6/g, 'gap-3');
content = content.replace(/gap-4 items-end/g, 'gap-2 items-end');
content = content.replace(/text-base font-medium/g, 'text-sm font-medium');
content = content.replace(/!text-base/g, '!text-sm');
content = content.replace(/mb-1 transition-colors/g, 'mb-0.5 transition-colors');
content = content.replace(/mb-1">Billing/g, 'mb-0.5">Billing');
content = content.replace(/mb-1">Document/g, 'mb-0.5">Document');
content = content.replace(/mb-1">Godown/g, 'mb-0.5">Godown');
content = content.replace(/!h-11/g, '!h-9');
content = content.replace(/w-11/g, 'w-9');
content = content.replace(/h-10/g, 'h-8'); // the old edit/print GC inputs
content = content.replace(/!mb-1/g, '!mb-0.5');
content = content.replace(/text-xs font-bold text-slate-500/g, 'text-[10px] font-bold text-slate-500');

fs.writeFileSync(file, content);
console.log('Done compacting GcEntry.jsx');
