import React, { useState } from 'react';
import { Save, User, Calculator, Truck, MapPin } from 'lucide-react';
import { Button } from '../components/ui/Button';
import Accordion from '../components/ui/Accordion';

export default function AccordionGcEntry() {
  const [openSection, setOpenSection] = useState('consignor');

  // Dummy state just for the demo
  const [form, setForm] = useState({
    consignorName: '',
    consigneeName: '',
    freight: '',
    weight: ''
  });

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
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1">Consignor Name</label>
              <input 
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all outline-none" 
                placeholder="Search Consignor..."
                value={form.consignorName}
                onChange={e => setForm({...form, consignorName: e.target.value})}
              />
            </div>
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1">GSTIN</label>
              <input 
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all outline-none" 
                placeholder="GSTIN Number"
              />
            </div>
            <div className="md:col-span-2 flex justify-end">
               <Button onClick={() => setOpenSection('consignee')} variant="secondary" className="text-xs py-1 h-8">Next: Consignee →</Button>
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
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1">Consignee Name</label>
              <input 
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all outline-none" 
                placeholder="Search Consignee..."
                value={form.consigneeName}
                onChange={e => setForm({...form, consigneeName: e.target.value})}
              />
            </div>
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1">Destination City</label>
              <input 
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all outline-none" 
                placeholder="City Name"
              />
            </div>
            <div className="md:col-span-2 flex justify-end">
               <Button onClick={() => setOpenSection('freight')} variant="secondary" className="text-xs py-1 h-8">Next: Freight →</Button>
            </div>
          </div>
        </Accordion>

        {/* SECTION 3: FREIGHT & GOODS */}
        <Accordion 
          title="3. Freight & Items" 
          icon={Calculator} 
          isOpen={openSection === 'freight'}
          onToggle={() => setOpenSection(openSection === 'freight' ? null : 'freight')}
        >
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1">Total Weight</label>
              <input 
                type="number"
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all outline-none font-mono" 
                placeholder="0.00"
              />
            </div>
            <div>
              <label className="block text-xs font-bold text-slate-500 mb-1">Freight Amount (₹)</label>
              <input 
                type="number"
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2 text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all outline-none font-mono text-indigo-700 font-bold" 
                placeholder="0.00"
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
        Notice how much cleaner the screen is when only one section is open at a time?
      </div>

    </div>
  );
}
