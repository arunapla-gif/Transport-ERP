import React, { useState } from 'react';
import { Save, FileText, Building2, MapPin, Package, Calculator, Camera, Plus, Trash2 } from 'lucide-react';
import { Button } from '../components/ui/Button';
import Accordion from '../components/ui/Accordion';

export default function AccordionGcEntry() {
  const [openSection, setOpenSection] = useState('document');
  const [companyMode, setCompanyMode] = useState('A');
  const [ewayBillNo, setEwayBillNo] = useState('');
  const [ewbPulse, setEwbPulse] = useState(false);

  // Dummy state mimicking the real NewGcEntry structure exactly
  const [form, setForm] = useState({
    date: new Date().toISOString().split('T')[0],
    time: new Date().toTimeString().split(' ')[0].substring(0, 5),
    godown: 'SIVAKASI MAIN',
    consignorName: '',
    consignorGstin: '',
    consigneeName: '',
    consigneeGstin: '',
    invoiceNo: '',
    invoiceValue: '',
    actualWeight: 'FIXED',
    freightType: 'To Pay',
    freightNote: ''
  });

  // Mimicking the Goods Array
  const [goods, setGoods] = useState([
    { id: 1, articles: '', units: 'Cases of Fireworks', description: '', amount: '' }
  ]);

  // Compute Summaries for Progressive Disclosure
  const documentSummary = form.godown ? `Godown: ${form.godown} | ${form.date} ${form.time}` : null;
  const consignorSummary = form.consignorName ? `${form.consignorName} ${form.consignorGstin ? `| GSTIN: ${form.consignorGstin}` : ''}` : null;
  const consigneeSummary = form.consigneeName ? `${form.consigneeName} ${form.consigneeGstin ? `| GSTIN: ${form.consigneeGstin}` : ''}` : null;
  
  const totalArticles = goods.reduce((sum, item) => sum + (parseInt(item.articles) || 0), 0);
  const goodsSummary = totalArticles > 0 || form.invoiceNo 
    ? `${totalArticles > 0 ? `${totalArticles} items` : ''} ${form.invoiceNo ? `| Inv: ${form.invoiceNo}` : ''} ${form.invoiceValue ? `| ₹${form.invoiceValue}` : ''}` 
    : null;

  const simulateEwbFetch = () => {
    // This simulates what happens when they click 'Fetch EWB'
    setCompanyMode('A');
    setForm(prev => ({
      ...prev,
      consignorName: 'Arun Fireworks (Auto-fetched)',
      consignorGstin: '33AAAAA0000A1Z5',
      consigneeName: 'Mega Traders (Auto-fetched)',
      consigneeGstin: '29BBBBB0000B1Z5',
      invoiceNo: 'INV-2026-99',
      invoiceValue: '150000'
    }));
    setGoods([{ id: 1, articles: '150', units: 'Cases of Fireworks', description: 'Assorted Crackers', amount: '' }]);
    // The magic of progressive disclosure: Auto-collapse 1,2,3,4 and open Freight!
    setOpenSection('freight');
    
    // Trigger the magic pulse for 3 seconds
    setEwbPulse(true);
    setTimeout(() => setEwbPulse(false), 3000);
  };

  return (
    <div className="flex flex-col flex-1 w-full mx-auto overflow-hidden bg-slate-100/50" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* 1:1 REPLICA OF YOUR TOP RIBBON */}
      <div className="bg-white border-b border-slate-200 p-3 flex justify-between items-center shrink-0 z-20 shadow-sm">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <span className="font-bold text-slate-800 text-lg">New GC (Acc Demo)</span>
            <div className="flex bg-slate-100 p-0.5 rounded-lg border border-slate-200">
               <button type="button" onClick={() => setCompanyMode('A')} className={`px-3 py-1 flex items-center justify-center text-xs font-bold rounded-md transition-all ${companyMode === 'A' ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}>AP</button>
               <button type="button" onClick={() => setCompanyMode('B')} className={`px-3 py-1 flex items-center justify-center text-xs font-bold rounded-md transition-all ${companyMode === 'B' ? 'bg-white text-emerald-700 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}>BELL</button>
            </div>
          </div>
          
          <div className="flex items-center gap-2 bg-indigo-50/50 p-1 rounded-lg border border-indigo-100">
             <input placeholder="Enter E-Way Bill" value={ewayBillNo} onChange={e => setEwayBillNo(e.target.value)} className="w-48 h-8 bg-white border border-slate-200 rounded px-2 text-sm outline-none focus:border-indigo-500" />
             <Button variant="primary" type="button" onClick={simulateEwbFetch} className="h-8 px-3 py-0 text-xs shadow-sm flex items-center gap-1">Fetch EWB</Button>
             <Button variant="success" type="button" className="h-8 w-8 p-0 flex items-center justify-center shadow-sm mr-2"><Camera size={14}/></Button>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <div className="bg-indigo-50 px-3 py-1.5 rounded-lg border border-indigo-100 text-indigo-700 font-bold text-sm flex items-center gap-2 ml-2">
            {companyMode === 'A' ? 'AP' : 'BELL'} - 5001
          </div>
          <Button variant="primary" className="h-9 px-6 text-xs shadow-md ml-4 font-bold">
            <Save size={14} className="mr-2" /> Save GC
          </Button>
        </div>
      </div>

      <div className="flex-1 flex overflow-hidden bg-slate-50/50">
        
        {/* LEFT COLUMN: THE ACCORDION WORKFLOW */}
        <div className="flex-1 overflow-y-auto p-4 md:p-6 lg:p-8 custom-scrollbar">
          <div className="max-w-4xl mx-auto flex flex-col gap-2">
        
            {/* SECTION 1: DOCUMENT & GODOWN */}
            <Accordion 
              title="1. Document Details" 
              icon={FileText} 
              isOpen={openSection === 'document'}
              onToggle={() => setOpenSection(openSection === 'document' ? null : 'document')}
              badge={form.godown ? "FILLED" : null}
              summary={documentSummary}
              defaultOpen={true}
              isCompleted={!!form.godown}
              isDimmed={openSection !== null && openSection !== 'document'}
            >
              <div className="grid grid-cols-1 md:grid-cols-4 gap-4 pb-2">
                <div>
                  <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Booking Date</label>
                  <input type="date" className="w-full bg-white border border-slate-200 rounded-lg p-2 text-sm shadow-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 outline-none h-9" 
                    value={form.date} onChange={e => setForm({...form, date: e.target.value})} />
                </div>
                <div>
                  <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Time</label>
                  <input type="time" className="w-full bg-white border border-slate-200 rounded-lg p-2 text-sm shadow-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 outline-none h-9" 
                    value={form.time} onChange={e => setForm({...form, time: e.target.value})} />
                </div>
                <div className="md:col-span-2">
                  <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Godown *</label>
                  <select className="w-full bg-white border border-slate-200 rounded-lg p-2 text-sm shadow-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 outline-none h-9"
                    value={form.godown} onChange={e => setForm({...form, godown: e.target.value})}>
                    <option value="">Select Godown...</option>
                    <option value="SIVAKASI MAIN">SIVAKASI MAIN</option>
                    <option value="BANGALORE">BANGALORE</option>
                  </select>
                </div>
                <div className="md:col-span-4 flex justify-end mt-2">
                   <Button onClick={() => setOpenSection('consignor')} variant="secondary" className="text-xs py-1 h-8 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 border-indigo-200 font-bold">Next: Consignor →</Button>
                </div>
              </div>
            </Accordion>

            {/* SECTION 2: CONSIGNOR */}
            <Accordion 
              title="2. Consignor Details" 
              icon={Building2} 
              isOpen={openSection === 'consignor'}
              onToggle={() => setOpenSection(openSection === 'consignor' ? null : 'consignor')}
              badge={form.consignorName ? "FILLED" : null}
              summary={consignorSummary}
              isCompleted={!!form.consignorName}
              isDimmed={openSection !== null && openSection !== 'consignor'}
            >
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pb-2">
                <div>
                  <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Search Consignor *</label>
                  <input 
                    className="w-full bg-white border border-slate-200 rounded-lg p-2 text-sm shadow-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 outline-none h-9" 
                    placeholder="Type to search live database..."
                    value={form.consignorName}
                    onChange={e => setForm({...form, consignorName: e.target.value})}
                  />
                </div>
                <div>
                  <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">GSTIN</label>
                  <input 
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm shadow-sm font-mono text-indigo-700 font-bold uppercase h-9" 
                    placeholder="Auto-filled GSTIN"
                    value={form.consignorGstin}
                    onChange={e => setForm({...form, consignorGstin: e.target.value})}
                  />
                </div>
                <div className="md:col-span-2">
                   <div className="relative text-xs text-slate-700 bg-[url('https://www.transparenttextures.com/patterns/cubes.png')] bg-white p-3 rounded-lg border border-slate-200 min-h-[60px] shadow-[inset_0_1px_3px_rgba(0,0,0,0.02)]">
                     <span className="absolute top-2 right-2 text-[8px] font-black tracking-wider text-slate-300 uppercase">Shipping Label</span>
                     {form.consignorName ? (
                       <div>
                         <span className="font-bold">{form.consignorName}</span><br />
                         123 Demo Street, Industrial Estate<br />
                         <span className="font-bold text-slate-900">SIVAKASI - 626123</span>
                       </div>
                     ) : (
                       <span className="text-slate-400 italic">Address Preview will appear here...</span>
                     )}
                   </div>
                </div>
                <div className="md:col-span-2 flex justify-end mt-2">
                   <Button onClick={() => setOpenSection('consignee')} variant="secondary" className="text-xs py-1 h-8 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 border-indigo-200 font-bold">Next: Consignee →</Button>
                </div>
              </div>
            </Accordion>

            {/* SECTION 3: CONSIGNEE */}
            <Accordion 
              title="3. Consignee Details" 
              icon={MapPin} 
              isOpen={openSection === 'consignee'}
              onToggle={() => setOpenSection(openSection === 'consignee' ? null : 'consignee')}
              badge={form.consigneeName ? "FILLED" : null}
              summary={consigneeSummary}
              isCompleted={!!form.consigneeName}
              isDimmed={openSection !== null && openSection !== 'consignee'}
            >
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pb-2">
                <div>
                  <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Search Consignee *</label>
                  <input 
                    className="w-full bg-white border border-slate-200 rounded-lg p-2 text-sm shadow-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 outline-none h-9" 
                    placeholder="Type to search live database..."
                    value={form.consigneeName}
                    onChange={e => setForm({...form, consigneeName: e.target.value})}
                  />
                </div>
                <div>
                  <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">GSTIN</label>
                  <input 
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm shadow-sm font-mono text-emerald-700 font-bold uppercase h-9" 
                    placeholder="Auto-filled GSTIN"
                    value={form.consigneeGstin}
                    onChange={e => setForm({...form, consigneeGstin: e.target.value})}
                  />
                </div>
                <div className="md:col-span-2 flex justify-end mt-2">
                   <Button onClick={() => setOpenSection('goods')} variant="secondary" className="text-xs py-1 h-8 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 border-indigo-200 font-bold">Next: Goods & Invoice →</Button>
                </div>
              </div>
            </Accordion>

            {/* SECTION 4: GOODS & INVOICE */}
            <Accordion 
              title="4. Goods & Invoice Details" 
              icon={Package} 
              isOpen={openSection === 'goods'}
              onToggle={() => setOpenSection(openSection === 'goods' ? null : 'goods')}
              badge={totalArticles > 0 ? "FILLED" : null}
              summary={goodsSummary}
              isCompleted={totalArticles > 0}
              isDimmed={openSection !== null && openSection !== 'goods'}
            >
              <div className="flex flex-col gap-4 pb-2">
                {/* Invoice Line */}
                <div className="grid grid-cols-4 gap-4 border-b border-slate-100 pb-4">
                  <div>
                    <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Invoice No</label>
                    <input type="text" className="w-full bg-white border border-slate-200 rounded-lg p-2 text-sm shadow-sm focus:border-indigo-500 outline-none h-9" 
                      value={form.invoiceNo} onChange={e => setForm({...form, invoiceNo: e.target.value})} />
                  </div>
                  <div>
                    <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Inv Value ₹</label>
                    <input type="number" className="w-full bg-amber-50 border border-amber-200 rounded-lg p-2 text-sm shadow-sm focus:border-amber-500 outline-none h-9 font-mono font-bold text-amber-900" 
                      value={form.invoiceValue} onChange={e => setForm({...form, invoiceValue: e.target.value})} />
                  </div>
                  <div>
                    <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Weight</label>
                    <input type="text" className="w-full bg-white border border-slate-200 rounded-lg p-2 text-sm shadow-sm focus:border-indigo-500 outline-none h-9" 
                      value={form.actualWeight} onChange={e => setForm({...form, actualWeight: e.target.value})} />
                  </div>
                </div>

                {/* Goods Array Simulation */}
                <div className="flex flex-col gap-2 bg-slate-100/50 p-3 rounded-lg border border-slate-200/50">
                  <div className="grid grid-cols-[80px_1fr_1fr_40px] gap-2 mb-1 px-1">
                    <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Qty</div>
                    <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Unit Desc</div>
                    <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Description</div>
                    <div></div>
                  </div>
                  
                  {goods.map((item, idx) => (
                    <div key={item.id} className="grid grid-cols-[80px_1fr_1fr_40px] gap-2 items-center bg-white p-1.5 rounded-lg border border-slate-200 shadow-sm">
                       <input type="number" className="w-full bg-transparent border-none p-1 text-sm outline-none font-mono text-center" 
                         value={item.articles} 
                         onChange={e => {
                           const newGoods = [...goods];
                           newGoods[idx].articles = e.target.value;
                           setGoods(newGoods);
                         }} placeholder="0" />
                         
                       <select className="w-full bg-transparent border-none p-1 text-sm outline-none" value={item.units} onChange={e => {
                         const newGoods = [...goods];
                         newGoods[idx].units = e.target.value;
                         setGoods(newGoods);
                       }}>
                         <option>Cases of Fireworks</option>
                         <option>Cartons</option>
                         <option>Bundles</option>
                       </select>
                       
                       <input type="text" className="w-full bg-transparent border-none p-1 text-sm outline-none" 
                         value={item.description} 
                         onChange={e => {
                           const newGoods = [...goods];
                           newGoods[idx].description = e.target.value;
                           setGoods(newGoods);
                         }} placeholder="Desc" />
                         
                       <button className="text-rose-500 hover:bg-rose-50 p-1.5 rounded-md flex justify-center"><Trash2 size={16}/></button>
                    </div>
                  ))}
                  
                  <div className="mt-2 flex justify-center">
                    <Button variant="secondary" className="h-8 text-xs flex gap-1 items-center bg-white" onClick={() => setGoods([...goods, { id: Date.now(), articles: '', units: 'Cases of Fireworks', description: '', amount: '' }])}>
                       <Plus size={14} /> Add Item Row
                    </Button>
                  </div>
                </div>

                <div className="flex justify-end mt-2">
                   <Button onClick={() => setOpenSection('freight')} variant="secondary" className="text-xs py-1 h-8 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 border-indigo-200 font-bold">Next: Final Freight →</Button>
                </div>
              </div>
            </Accordion>

            {/* SECTION 5: FREIGHT (FINAL) */}
            <Accordion 
              title="5. Freight & Finalize" 
              icon={Calculator} 
              isOpen={openSection === 'freight'}
              onToggle={() => setOpenSection(openSection === 'freight' ? null : 'freight')}
              isCompleted={!!form.freightAmount} // Added dummy field check for completion visual
              isDimmed={openSection !== null && openSection !== 'freight'}
            >
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pb-2">
                <div>
                  <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5 flex items-center justify-between">
                    Freight Amount (₹)
                    {ewbPulse && <span className="text-[9px] font-black text-indigo-500 animate-pulse bg-indigo-50 px-1.5 rounded">AUTO-NAVIGATED</span>}
                  </label>
                  <input type="number" 
                    className={`w-full border rounded-lg p-3 text-2xl shadow-sm outline-none font-mono font-bold transition-all duration-500 ${ewbPulse ? 'border-indigo-500 ring-4 ring-indigo-500/20 bg-indigo-50/30 text-indigo-900' : 'bg-emerald-50/30 border-emerald-200 focus:border-emerald-500 text-emerald-800'}`}
                    placeholder="0.00" 
                    value={form.freightAmount} 
                    onChange={e => setForm({...form, freightAmount: e.target.value})} 
                    autoFocus={ewbPulse}
                  />
                </div>
                <div className="flex flex-col gap-3">
                  <div>
                    <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Payment Type</label>
                    <select className="w-full bg-white border border-slate-200 rounded-lg p-2 text-sm shadow-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 outline-none h-9"
                      value={form.freightType} onChange={e => setForm({...form, freightType: e.target.value})}>
                      <option>To Pay</option>
                      <option>Paid</option>
                      <option>Account</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Freight Note (Optional)</label>
                    <input type="text" className="w-full bg-white border border-slate-200 rounded-lg p-2 text-sm shadow-sm focus:border-indigo-500 outline-none h-9" 
                      value={form.freightNote} onChange={e => setForm({...form, freightNote: e.target.value})} />
                  </div>
                </div>
              </div>
            </Accordion>

          </div>
        </div>

        {/* RIGHT COLUMN: LIVE GC PREVIEW TICKET */}
        <div className="hidden lg:block w-[340px] xl:w-[400px] border-l border-slate-200 bg-slate-100 p-4 xl:p-6 shrink-0 relative">
           <div className="sticky top-6 flex flex-col h-[calc(100vh-140px)]">
             <div className="flex items-center justify-between mb-3">
               <h3 className="font-black text-slate-700 text-xs tracking-widest uppercase">Live GC Preview</h3>
               <span className="text-[10px] font-bold text-slate-400 bg-white px-2 py-0.5 rounded-full border border-slate-200 shadow-sm">{companyMode === 'A' ? 'AP' : 'BELL'} LOGISTICS</span>
             </div>

             {/* The Receipt Ticket */}
             <div className="flex-1 bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col relative">
                {/* Ticket Jagged Top - purely CSS decorative */}
                <div className="h-2 w-full bg-[url('data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI4IiBoZWlnaHQ9IjgiPgo8cGF0aCBkPSJNMCAwIEw0IDggTDggMCBaIiBmaWxsPSIjZjFmNWY5Ii8+Cjwvc3ZnPg==')] absolute top-0 left-0 bg-repeat-x z-10 opacity-50"></div>
                
                <div className="p-5 pt-6 flex-1 overflow-y-auto custom-scrollbar">
                  <div className="text-center mb-4 pb-4 border-b border-dashed border-slate-300">
                    <div className="font-bold text-slate-800 text-lg mb-1">{form.consignorName || '---'}</div>
                    <div className="text-xs text-slate-500 font-medium">TO</div>
                    <div className="font-bold text-slate-800 text-lg mt-1">{form.consigneeName || '---'}</div>
                  </div>

                  <div className="space-y-3 text-sm">
                    <div className="flex justify-between">
                      <span className="text-slate-500 text-xs">Date</span>
                      <span className="font-mono font-bold text-slate-700 text-xs">{form.date}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500 text-xs">Godown</span>
                      <span className="font-bold text-slate-700 text-xs">{form.godown || '---'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500 text-xs">Articles</span>
                      <span className="font-bold text-slate-700 text-xs">{totalArticles > 0 ? `${totalArticles} items` : '---'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500 text-xs">Inv Value</span>
                      <span className="font-mono font-bold text-slate-700 text-xs">₹ {form.invoiceValue || '0.00'}</span>
                    </div>
                  </div>

                  {totalArticles > 0 && (
                    <div className="mt-4 pt-4 border-t border-dashed border-slate-300">
                      <div className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">Item Breakdown</div>
                      {goods.map((item, idx) => item.articles ? (
                        <div key={idx} className="flex justify-between text-xs mb-1">
                          <span className="text-slate-600">{item.articles}x {item.units.split(' ')[0]}</span>
                          <span className="text-slate-400 truncate ml-2 max-w-[120px]">{item.description}</span>
                        </div>
                      ) : null)}
                    </div>
                  )}
                </div>

                <div className="bg-slate-800 text-white p-4">
                  <div className="flex justify-between items-end">
                    <div className="flex flex-col">
                      <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Total Freight</span>
                      <span className="text-xs text-slate-300">{form.freightType}</span>
                    </div>
                    <span className="text-2xl font-mono font-bold">₹ {form.freightAmount || '0.00'}</span>
                  </div>
                </div>
             </div>
           </div>
        </div>

      </div>
    </div>
  );
}
