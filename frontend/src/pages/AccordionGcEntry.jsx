import React, { useState } from 'react';
import { Save, User, Calculator, Truck, MapPin } from 'lucide-react';
import { Button } from '../components/ui/Button';
import Accordion from '../components/ui/Accordion';

export default function AccordionGcEntry() {
  const [openSection, setOpenSection] = useState('consignor');

  // Dummy state just for the demo
  const [form, setForm] = useState({
    consignorName: '',
    consignorGstin: '',
    consigneeName: '',
    consigneeCity: '',
    freight: '',
    weight: ''
  });

  // Compute Summaries for closed accordions
  const consignorSummary = form.consignorName 
    ? `${form.consignorName} ${form.consignorGstin ? `| GSTIN: ${form.consignorGstin}` : ''}`
    : null;

  const consigneeSummary = form.consigneeName 
    ? `${form.consigneeName} ${form.consigneeCity ? `| City: ${form.consigneeCity}` : ''}`
    : null;
    
  const freightSummary = form.freight || form.weight
    ? `${form.weight ? `${form.weight}kg` : ''} ${form.freight && form.weight ? '|' : ''} ${form.freight ? `₹${form.freight}` : ''}`
    : null;

  return (
    <div className="flex flex-col flex-1 w-full max-w-4xl mx-auto p-4 md:p-6 bg-slate-50 overflow-y-auto h-full" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-black tracking-tight text-slate-800">New GC (Accordion Prototype)</h1>
          <p className="text-sm text-slate-500 font-medium">This is a safe playground to test the Accordion UI.</p>
        </div>
        <Button variant="primary" className="shadow-md">
          <Save size={16} className="mr-2" />
          Save GC
        </Button>
      </div>

      <div className="flex flex-col gap-2">
        
        {/* SECTION 1: CONSIGNOR */}
        <Accordion 
          title="1. Consignor Details" 
          icon={User} 
          isOpen={openSection === 'consignor'}
          onToggle={() => setOpenSection(openSection === 'consignor' ? null : 'consignor')}
          badge={form.consignorName ? "FILLED" : null}
          summary={consignorSummary}
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1">Consignor Name (Search Simulation)</label>
              <input 
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all outline-none" 
                placeholder="Type 'Arun Fireworks'..."
                value={form.consignorName}
                onChange={e => setForm({...form, consignorName: e.target.value})}
              />
            </div>
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1">GSTIN</label>
              <input 
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all outline-none" 
                placeholder="GSTIN Number"
                value={form.consignorGstin}
                onChange={e => setForm({...form, consignorGstin: e.target.value})}
              />
            </div>
            <div className="md:col-span-2 flex justify-end">
               <Button onClick={() => setOpenSection('consignee')} variant="secondary" className="text-xs py-1 h-8 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 border-indigo-200">Next: Consignee →</Button>
            </div>
          </div>
        </Accordion>

        {/* SECTION 2: CONSIGNEE */}
        <Accordion 
          title="2. Consignee Details" 
          icon={MapPin} 
          isOpen={openSection === 'consignee'}
          onToggle={() => setOpenSection(openSection === 'consignee' ? null : 'consignee')}
          badge={form.consigneeName ? "FILLED" : null}
          summary={consigneeSummary}
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1">Consignee Name (Search Simulation)</label>
              <input 
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all outline-none" 
                placeholder="Type 'Mega Traders'..."
                value={form.consigneeName}
                onChange={e => setForm({...form, consigneeName: e.target.value})}
              />
            </div>
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1">Destination City</label>
              <input 
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all outline-none" 
                placeholder="City Name"
                value={form.consigneeCity}
                onChange={e => setForm({...form, consigneeCity: e.target.value})}
              />
            </div>
            <div className="md:col-span-2 flex justify-end">
               <Button onClick={() => setOpenSection('freight')} variant="secondary" className="text-xs py-1 h-8 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 border-indigo-200">Next: Freight →</Button>
            </div>
          </div>
        </Accordion>

        {/* SECTION 3: FREIGHT & GOODS */}
        <Accordion 
          title="3. Freight & Items" 
          icon={Calculator} 
          isOpen={openSection === 'freight'}
          onToggle={() => setOpenSection(openSection === 'freight' ? null : 'freight')}
          badge={form.freight ? "FILLED" : null}
          summary={freightSummary}
        >
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1">Total Weight</label>
              <input 
                type="number"
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all outline-none font-mono" 
                placeholder="0.00"
                value={form.weight}
                onChange={e => setForm({...form, weight: e.target.value})}
              />
            </div>
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1">Freight Amount (₹)</label>
              <input 
                type="number"
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all outline-none font-mono text-indigo-700 font-bold" 
                placeholder="0.00"
                value={form.freight}
                onChange={e => setForm({...form, freight: e.target.value})}
              />
            </div>
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1">Payment Type</label>
              <select className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all outline-none">
                <option>To Pay</option>
                <option>Paid</option>
                <option>Account</option>
              </select>
            </div>
          </div>
        </Accordion>

      </div>
      
      <div className="mt-8 flex justify-center text-xs text-slate-400 font-medium pb-10">
        Notice how the closed tabs now display a summary of what you entered?
      </div>

    </div>
  );
}
