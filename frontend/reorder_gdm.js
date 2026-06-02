const fs = require('fs');
const path = require('path');

const filePath = path.join('/Users/arun_ap/Desktop/TRANSPORT ERP/frontend/src/pages/GdmEntry.jsx');
let content = fs.readFileSync(filePath, 'utf-8');

// The layout starts after the success message
const layoutStartStr = `<div className="grid grid-cols-1 lg:grid-cols-12 gap-4">`;
const layoutStartIndex = content.indexOf(layoutStartStr);

if (layoutStartIndex === -1) {
  console.error("Could not find layout start");
  process.exit(1);
}

// Identify chunks
const headerCardStart = content.indexOf('<GlassCard>', layoutStartIndex);
const headerCardEnd = content.indexOf('</GlassCard>', headerCardStart) + '</GlassCard>'.length;
const headerCardCode = content.substring(headerCardStart, headerCardEnd);

const lorryCardStart = content.indexOf('<GlassCard>', headerCardEnd);
const lorryCardEnd = content.indexOf('</GlassCard>', lorryCardStart) + '</GlassCard>'.length;
const lorryCardCode = content.substring(lorryCardStart, lorryCardEnd);

const despatchCardStart = content.indexOf('<GlassCard className="h-full flex flex-col">', lorryCardEnd);
const despatchCardEnd = content.indexOf('</GlassCard>', despatchCardStart) + '</GlassCard>'.length;
const despatchCardCode = content.substring(despatchCardStart, despatchCardEnd);

const everythingBefore = content.substring(0, layoutStartIndex);
// Find the end of the layout block. The grid div closes right after the despatch card's right column div closes.
// Actually, let's just find the final closing tags of the component.
const endOfReturn = content.indexOf('</div>\n    </div>\n  );\n}');

const newLayout = `
      {/* TOP ROW: Lorry & Memo Details */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Lorry Details (Left) */}
        ${lorryCardCode}

        {/* Delivery Memo (Right) */}
        ${headerCardCode}
      </div>

      {/* BOTTOM ROW: Despatch List */}
      <div className="mt-4">
        ${despatchCardCode}
      </div>
`;

const finalContent = everythingBefore + newLayout + '\n    </div>\n  );\n}';

fs.writeFileSync(filePath, finalContent, 'utf-8');
console.log("Successfully restructured GdmEntry layout.");
