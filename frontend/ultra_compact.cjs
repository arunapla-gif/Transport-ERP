const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, 'src', 'pages', 'GcEntry.jsx');
let content = fs.readFileSync(file, 'utf8');

// Replace Primitives
const primitivesRegex = /\/\/ Specialized input primitives[\s\S]*?\/\/ Glassmorphic Card Wrapper Component \([^)]+\)[\s\S]*?const GlassCard = \(\{ children, className = "" \}\) => \([\s\S]*?<\/div>\n\);/m;

const newPrimitives = `// Ultra simple compact primitives
const DenseInput = ({ label, className = "", ...props }) => (
  <div className={\`flex flex-col group \${className}\`}>
    {label && <label className="text-[10px] font-bold text-gray-700 uppercase mb-0.5">{label}</label>}
    <input 
      className="w-full h-7 px-2 border border-gray-300 rounded-sm bg-white text-xs font-medium text-gray-900 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500" 
      {...props} 
    />
  </div>
);

const DenseSelect = ({ label, options, className = "", ...props }) => (
  <div className={\`flex flex-col group \${className}\`}>
    {label && <label className="text-[10px] font-bold text-gray-700 uppercase mb-0.5">{label}</label>}
    <select 
      className="w-full h-7 px-1 border border-gray-300 rounded-sm bg-white text-xs font-medium text-gray-900 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500" 
      {...props}
    >
      {options.map((opt, i) => (
        <option key={i} value={opt.value || opt}>{opt.label || opt}</option>
      ))}
    </select>
  </div>
);

const denseSearchableSelectClass = "[&>label]:!text-[10px] [&>label]:!font-bold [&>label]:!text-gray-700 [&>label]:!mb-0.5 [&>div:nth-of-type(1)]:!h-7 [&>div:nth-of-type(1)]:!min-h-0 [&>div:nth-of-type(1)]:!py-0 [&>div:nth-of-type(1)]:!rounded-sm [&>div:nth-of-type(1)]:!border-gray-300 [&>div:nth-of-type(1)>input]:!text-xs [&>div:nth-of-type(1)>div]:!text-xs [&>div:nth-of-type(1)>svg]:!w-4 [&>div:nth-of-type(1)>svg]:!h-4";

const GlassCard = ({ children, className = "" }) => (
  <div className={\`bg-white border border-gray-300 rounded-sm p-3 flex flex-col \${className}\`}>
    {children}
  </div>
);`;

content = content.replace(primitivesRegex, newPrimitives);

// Replace heights and sizings
content = content.replace(/h-9/g, 'h-7');
content = content.replace(/w-9/g, 'w-7');
content = content.replace(/h-8/g, 'h-7');
content = content.replace(/w-8/g, 'w-7');
content = content.replace(/gap-6/g, 'gap-3');
content = content.replace(/gap-4/g, 'gap-2');
content = content.replace(/p-1\.5/g, 'p-1');
content = content.replace(/px-4/g, 'px-2');
content = content.replace(/px-5/g, 'px-3');
content = content.replace(/px-3/g, 'px-2');
content = content.replace(/py-2\.5/g, 'py-1');
content = content.replace(/px-\[18px\]/g, 'px-2');

// Clean up background colors and heavy styling
content = content.replace(/bg-slate-50\/50/g, 'bg-gray-100');
content = content.replace(/bg-slate-100\/50/g, 'bg-gray-100');
content = content.replace(/bg-indigo-50\/50/g, 'bg-gray-50');
content = content.replace(/backdrop-blur-sm/g, '');
content = content.replace(/shadow-sm/g, '');
content = content.replace(/rounded-xl/g, 'rounded-sm');
content = content.replace(/rounded-lg/g, 'rounded-sm');
content = content.replace(/rounded-md/g, 'rounded-sm');
content = content.replace(/border-slate-200/g, 'border-gray-300');
content = content.replace(/text-slate-/g, 'text-gray-');

// Make submit button smaller
content = content.replace(/h-11 px-8/g, 'h-8 px-4');
content = content.replace(/h-11 px-6/g, 'h-8 px-3');

// Fix text classes
content = content.replace(/text-sm/g, 'text-xs');
content = content.replace(/text-base/g, 'text-sm');
content = content.replace(/text-lg/g, 'text-sm');

// Remove icons from section headers
content = content.replace(/<div className="bg-.*?-50.*?>.*?(?:MapPin|Building2|Receipt|Package|Wallet|Camera).*?<\/div>/g, '');
content = content.replace(/<Camera size=\{18\}.*?\/>/g, 'QR');
content = content.replace(/<FileText size=\{18\}.*?\/>/g, 'Print');

fs.writeFileSync(file, content);
console.log('Done ultra-compacting GcEntry.jsx');
