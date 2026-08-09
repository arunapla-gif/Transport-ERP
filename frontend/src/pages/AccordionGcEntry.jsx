import React, { useState } from 'react';
import { Save, FileText, Building2, MapPin, Package, Calculator } from 'lucide-react';
import { Button } from '../components/ui/Button';
import Accordion from '../components/ui/Accordion';

export default function AccordionGcEntry() {
  const [openSection, setOpenSection] = useState('document');

  // Dummy state mimicking the real NewGcEntry structure
  const [form, setForm] = useState({
    date: new Date().toISOString().split('T')[0],
    time: new Date().toTimeString().split(' ')[0].substring(0, 5),
    godown: '',
    consignorName: '',
    consignorGstin: '',
    consigneeName: '',
    consigneeGstin: '',
    invoiceNo: '',
    invoiceValue: '',
    qty: '',
    goodsDesc: '',
    freightType: 'To Pay',
    freightNote: ''
  });

  // Compute Summaries for Progressive Disclosure
  const documentSummary = form.godown ? `Godown: ${form.godown} | ${form.date} ${form.time}` : null;
  const consignorSummary = form.consignorName ? `${form.consignorName} ${form.consignorGstin ? `| GSTIN: ${form.consignorGstin}` : ''}` : null;
  const consigneeSummary = form.consigneeName ? `${form.consigneeName} ${form.consigneeGstin ? `| GSTIN: ${form.consigneeGstin}` : ''}` : null;
  const goodsSummary = form.qty || form.invoiceNo ? `${form.qty ? `${form.qty} items` : ''} ${form.invoiceNo ? `| Inv: ${form.invoiceNo}` : ''} ${form.invoiceValue ? `| ₹${form.invoiceValue}` : ''}` : null;

  return (
    <div className="flex flex-col flex-1 w-full max-w-4xl mx-auto p-4 md:p-6 bg-slate-50 overflow-y-auto h-full" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-black tracking-tight text-slate-800">New GC (Accordion Prototype)</h1>
          <p className="text-sm text-slate-500 font-medium">Mapped exactly to your live GC Entry fields.</p>
        </div>
        <Button variant="primary" className="shadow-md h-10 px-6 font-bold text-sm">
          <Save size={16} className="mr-2" />
          Save GC
        </Button>
      </div>

      <div className="flex flex-col gap-2">
        
        {/* SECTION 1: DOCUMENT & GODOWN */}
        <Accordion 
          title="1. Document Details" 
          icon={FileText} 
          isOpen={openSection === 'document'}
          onToggle={() => setOpenSection(openSection === 'document' ? null : 'document')}
          badge={form.godown ? "FILLED" : null}
          summary={documentSummary}
          defaultOpen={true}
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
               <div className="text-xs text-slate-500 bg-slate-50 p-2.5 rounded border border-slate-100 min-h-[40px] italic">
                 {form.consignorName ? `123 Demo Street, Sivakasi (Address auto-filled)` : 'Address Preview will appear here...'}
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
          badge={form.qty ? "FILLED" : null}
          summary={goodsSummary}
        >
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 pb-2">
            <div>
              <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Invoice No</label>
              <input type="text" className="w-full bg-white border border-slate-200 rounded-lg p-2 text-sm shadow-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 outline-none h-9" 
                value={form.invoiceNo} onChange={e => setForm({...form, invoiceNo: e.target.value})} />
            </div>
            <div>
              <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Inv Value ₹</label>
              <input type="number" className="w-full bg-amber-50 border border-amber-200 rounded-lg p-2 text-sm shadow-sm focus:border-amber-500 outline-none h-9 font-mono font-bold text-amber-900" 
                value={form.invoiceValue} onChange={e => setForm({...form, invoiceValue: e.target.value})} />
            </div>
            <div className="md:col-span-2">
               {/* Spacer */}
            </div>

            {/* Goods Table Simulation */}
            <div className="md:col-span-4 bg-slate-100/50 p-3 rounded-lg border border-slate-200/50 mt-2">
               <div className="grid grid-cols-[80px_1fr] gap-3">
                 <div>
                    <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Qty</label>
                    <input type="number" className="w-full bg-white border border-slate-200 rounded p-1.5 text-sm shadow-sm focus:border-indigo-500 outline-none h-8 font-mono" 
                      value={form.qty} onChange={e => setForm({...form, qty: e.target.value})} />
                 </div>
                 <div>
                    <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5">Description of Goods</label>
                    <input type="text" className="w-full bg-white border border-slate-200 rounded p-1.5 text-sm shadow-sm focus:border-indigo-500 outline-none h-8" 
                      placeholder="e.g. Cases of Fireworks"
                      value={form.goodsDesc} onChange={e => setForm({...form, goodsDesc: e.target.value})} />
                 </div>
               </div>
            </div>

            <div className="md:col-span-4 flex justify-end mt-2">
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
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pb-2">
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
        </Accordion>

      </div>
      
    </div>
  );
}
