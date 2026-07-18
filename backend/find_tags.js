const fs = require('fs');
const content = fs.readFileSync('/Users/arun_ap/Desktop/TRANSPORT ERP/frontend/src/pages/GdmEntry.jsx', 'utf8');

// A very naive JSX tag stack counter
const lines = content.split('\n');
const stack = [];

for (let i = 890; i < 1250; i++) {
  const line = lines[i];
  if (!line) continue;
  
  // match <div ...> and </div> and <GlassCard> and </GlassCard>
  const tags = line.match(/<div|<\/div>|<GlassCard|<\/GlassCard>/g);
  if (tags) {
    for (const tag of tags) {
      if (tag === '<div') stack.push({ tag: 'div', line: i+1 });
      else if (tag === '<GlassCard') stack.push({ tag: 'GlassCard', line: i+1 });
      else if (tag === '</div>') {
        const last = stack.pop();
        if (!last || last.tag !== 'div') {
           console.log(`Mismatched </div> at line ${i+1}. Last open tag was ${last ? last.tag + ' at ' + last.line : 'NONE'}`);
        }
      }
      else if (tag === '</GlassCard>') {
        const last = stack.pop();
        if (!last || last.tag !== 'GlassCard') {
           console.log(`Mismatched </GlassCard> at line ${i+1}. Last open tag was ${last ? last.tag + ' at ' + last.line : 'NONE'}`);
        }
      }
    }
  }
}
console.log("Remaining stack:");
console.log(stack);
