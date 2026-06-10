const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, 'src', 'pages', 'GcEntry.jsx');
let content = fs.readFileSync(file, 'utf8');

const returnRegex = /return \([\s\S]*?\n\);/m;

const newReturn = `return (
    <div className="flex flex-col h-[calc(100vh-60px)] overflow-hidden bg-slate-200" style={{ fontFamily: 'sans-serif' }}>
      
      {/* Top action bar */}
      <div className="shrink-0 bg-white p-3 border-b flex justify-between items-center z-20 shadow-sm">
        <div className="flex gap-2 items-center">
          <label className="font-bold text-sm text-slate-600">Edit / Load GC:</label>
          <input 
            placeholder="GC Number" 
            value={searchEditGc} 
            onChange={e => setSearchEditGc(e.target.value)} 
            onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); loadGcForEdit(); } }}
            className="border border-slate-300 px-2 py-1.5 rounded text-sm w-32 focus:outline-none focus:border-indigo-500 font-bold" 
          />
          <button onClick={loadGcForEdit} disabled={loading} className="bg-amber-500 text-white px-4 py-1.5 rounded text-sm font-bold shadow-sm">Load</button>
          <button onClick={() => { if (searchEditGc) setShowPrintModal(true); }} className="bg-indigo-100 text-indigo-700 px-4 py-1.5 rounded text-sm font-bold shadow-sm">Print</button>
        </div>
        <div className="flex gap-3 items-center">
          {error && <span className="text-rose-600 font-bold text-sm mr-2">{error}</span>}
          {success && <span className="text-emerald-600 font-bold text-sm mr-2">{success}</span>}
          <button onClick={handleReset} className="border border-slate-300 px-5 py-1.5 rounded bg-white text-sm font-bold hover:bg-slate-50 shadow-sm">Reset</button>
          <button onClick={handleSaveGC} disabled={loading} className="bg-indigo-600 text-white px-8 py-1.5 rounded font-bold text-sm hover:bg-indigo-700 shadow-sm">
             {loading ? 'Wait...' : (activeGcId ? 'Update GC' : 'Submit GC')}
          </button>
        </div>
      </div>

      {/* Scrollable WYSIWYG Area */}
      <div className="flex-1 overflow-y-auto p-4 md:p-8 flex flex-col items-center custom-scrollbar">
        
        {/* Main WYSIWYG Paper */}
        <div className="w-[210mm] max-w-full bg-white text-black font-sans text-xs p-4 md:p-6 shadow-2xl relative mb-10">
          
          {/* Company Toggle / Eway Bill Utilities */}
          <div className="flex justify-between items-center mb-4 border-b border-slate-200 pb-3">
             <div className="flex gap-2 items-center">
               <span className="font-bold text-slate-500 text-[10px] uppercase">Entity:</span>
               <button onClick={() => handleCompanyToggle('A')} className={\`px-3 py-1 border text-xs font-bold rounded \${gcDetails.companyMode === 'A' ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-slate-100'}\`}>AP</button>
               <button onClick={() => handleCompanyToggle('B')} className={\`px-3 py-1 border text-xs font-bold rounded \${gcDetails.companyMode === 'B' ? 'bg-emerald-600 text-white border-emerald-600' : 'bg-slate-100'}\`}>BELL</button>
             </div>
             <div className="flex gap-2 items-center">
               <span className="font-bold text-slate-500 text-[10px] uppercase">E-Way Bill:</span>
               <input placeholder="Enter EWB" value={ewayBillNo} onChange={e => setEwayBillNo(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') { handleEwayBillSearch(); } }} className="border border-slate-300 rounded px-2 py-1 text-xs w-36 focus:outline-none focus:border-indigo-500 font-bold"/>
               <button onClick={handleEwayBillSearch} className="bg-slate-800 text-white px-3 py-1 rounded text-xs font-bold shadow-sm">Fetch</button>
               {fetchedEwbDetails && <button onClick={handleReassignTransporter} className="bg-amber-500 text-white px-3 py-1 rounded text-xs font-bold shadow-sm border border-amber-600">Reassign</button>}
             </div>
          </div>

          {/* --- SUPER HEADER --- */}
          <div className="flex justify-between items-end font-bold mb-1 px-1">
            <div className="w-1/3"></div>
            <div className="text-center w-1/3 text-[14px]">GOODS CONSIGNMENT NOTE</div>
            <div className="text-right w-1/3 text-[12px]">(ORIGINAL COPY)</div>
          </div>

          {/* --- MAIN BORDER WRAPPER --- */}
          <div className="border border-black">
            
            {/* ROW 1: HEADER LOGO AND COMPANY */}
            <div className="flex border-b border-black p-2 items-center">
              <div className="w-[20%] flex justify-center items-center">
                 <div className="relative font-serif font-bold text-[45px] leading-none italic tracking-tighter text-blue-900 flex items-center pr-4">
                   <span className="z-10 bg-white px-1">{gcDetails.companyMode === 'A' ? 'A' : 'B'}</span>
                   <span className="text-[32px] ml-[-4px] mt-2 z-10 bg-white px-1">{gcDetails.companyMode === 'A' ? 'P' : 'L'}</span>
                 </div>
              </div>
              <div className="w-[80%] text-center leading-tight pr-10">
                 <div className="text-[10px] font-bold mb-0.5">{gcDetails.companyMode === 'A' ? 'ஸ்ரீ அய்யனார் துணை' : 'ஸ்ரீ திருச்செந்தூர் முருகன் துணை'}</div>
                 <div className="text-[24px] font-black text-blue-600 tracking-wide uppercase mb-0.5">{gcDetails.companyMode === 'A' ? 'A.P. ROADLINES' : 'THE BELL LORRY AGENCIES'}</div>
                 <div className="text-[12px] font-bold">{gcDetails.companyMode === 'A' ? 'SIVAKASI' : '359, THIRUTHAGAL ROAD, SIVAKASI-626123'}</div>
              </div>
            </div>

            {/* ROW 2: CONSIGNOR, CONSIGNEE, GC NO */}
            <div className="flex border-b border-black">
              <div className="w-[35%] border-r border-black p-2 align-top flex flex-col min-h-[70px]">
                 <div className="font-bold text-[11px] mb-1">Consignor:</div>
                 <select value={partyDetails.consignorId || ''} onChange={handleConsignorChange} className="w-full text-[11px] uppercase font-bold outline-none bg-yellow-50 border-b border-dashed border-slate-300 mb-1 py-0.5 cursor-pointer">
                   <option value="">Select Consignor...</option>
                   {consignors.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
                 </select>
                 <div className="text-[10px] uppercase leading-tight mt-0.5">{partyDetails.consignorAddressPreview || '-'}</div>
                 <div className="text-[10px] uppercase mt-1 font-bold">GSTIN: {partyDetails.consignorGstin || '-'}</div>
              </div>
              <div className="w-[45%] border-r border-black p-2 align-top flex flex-col relative">
                 <div className="font-bold text-[11px] mb-1">Consignee:</div>
                 <select value={partyDetails.consigneeId || ''} onChange={handleConsigneeChange} className="w-full text-[11px] uppercase font-bold outline-none bg-yellow-50 border-b border-dashed border-slate-300 mb-1 py-0.5 cursor-pointer">
                   <option value="">Select Consignee...</option>
                   {consignees.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
                 </select>
                 <div className="text-[10px] uppercase mt-0.5">{partyDetails.consigneeAddressPreview || '-'}</div>
                 <div className="text-[10px] uppercase mt-1 font-bold">GSTIN: {partyDetails.consigneeGstin || '-'}</div>
              </div>
              <div className="w-[20%] p-2 flex flex-col gap-1.5 justify-center">
                 <div className="flex gap-1 text-[12px] items-center">
                   <span className="font-bold whitespace-nowrap">GC No :</span>
                   <input value={gcDetails.gcNumber} onChange={e => setGcDetails({...gcDetails, gcNumber: e.target.value})} className="w-full font-bold outline-none bg-yellow-50 px-1 border-b border-slate-300" />
                 </div>
                 <div className="flex gap-1 text-[12px] items-center">
                   <span className="font-bold whitespace-nowrap">Date :</span>
                   <input type="date" value={gcDetails.date} onChange={e => setGcDetails({...gcDetails, date: e.target.value})} className="w-full font-bold outline-none bg-yellow-50 text-[10px] px-1 border-b border-slate-300" />
                 </div>
                 <div className="flex gap-1 text-[12px] items-center">
                   <span className="font-bold whitespace-nowrap">Godown:</span>
                   <select value={gcDetails.godown || ''} onChange={e => setGcDetails({...gcDetails, godown: e.target.value})} className="w-full text-[10px] font-bold outline-none bg-yellow-50 px-1 border-b border-slate-300 cursor-pointer">
                     <option value="">Select...</option>
                     {godowns.map(g => <option key={g.id} value={g.name}>{g.name}</option>)}
                   </select>
                 </div>
              </div>
            </div>

            {/* ROW 3: FROM / TO */}
            <div className="flex border-b border-black font-bold text-[12px]">
              <div className="w-[50%] border-r border-black p-1.5 flex gap-2">
                 From : <span>SIVAKASI</span>
              </div>
              <div className="w-[50%] p-1.5 uppercase flex gap-2 items-center">
                 To : <span className="px-1 text-indigo-700 font-black">{consignees.find(c => c.id === parseInt(partyDetails.consigneeId))?.city || '-------'}</span>
              </div>
            </div>

            {/* ROW 4: TABLE */}
            <div className="flex min-h-[160px]">
              
              {/* QTY & DESC COLUMNS */}
              <div className="w-[55%] flex">
                <div className="w-[30%] border-r border-black flex flex-col">
                   <div className="border-b border-black p-1 text-center font-bold text-[11px]">No of Articles</div>
                   <div className="p-1 flex flex-col gap-1.5">
                      {goods.map((g, i) => (
                        <div key={g.id} className="flex gap-1">
                          <input type="number" placeholder="Qty" value={g.articles} onChange={(e) => setGoods(goods.map(item => item.id === g.id ? {...item, articles: e.target.value} : item))} className="w-2/3 outline-none bg-yellow-50 border border-yellow-200 px-1 text-center font-bold" />
                          <input value={g.units} placeholder="Unit" onChange={(e) => setGoods(goods.map(item => item.id === g.id ? {...item, units: e.target.value} : item))} className="w-1/3 outline-none bg-yellow-50 border border-yellow-200 px-1 text-[10px]" />
                        </div>
                      ))}
                      <button onClick={addRow} className="text-[10px] bg-slate-100 border border-slate-300 hover:bg-slate-200 text-slate-700 py-0.5 rounded font-bold text-center mt-1 mx-1">+ Add Row</button>
                   </div>
                </div>
                <div className="w-[70%] border-r border-black flex flex-col">
                   <div className="border-b border-black p-1 text-center font-bold text-[11px]">Description</div>
                   <div className="p-1 flex flex-col gap-1.5">
                      {goods.map((g, i) => (
                        <div key={g.id} className="flex gap-1 relative group">
                          <input value={g.description} onChange={(e) => setGoods(goods.map(item => item.id === g.id ? {...item, description: e.target.value} : item))} className="w-full outline-none bg-yellow-50 border border-yellow-200 px-1 uppercase font-bold text-[11px]" placeholder="Item Description" />
                          <button onClick={() => removeRow(g.id)} className="absolute -right-5 text-red-500 opacity-0 group-hover:opacity-100 text-xs font-bold hover:bg-red-50 px-1 rounded">×</button>
                        </div>
                      ))}
                   </div>
                </div>
              </div>

              {/* RATE COLUMN */}
              <div className="w-[10%] border-r border-black flex flex-col">
                 <div className="border-b border-black p-1 text-center font-bold text-[11px]">Rate</div>
                 <div className="p-1 text-center text-[11px]">
                    0.00
                 </div>
              </div>

              {/* FREIGHT COLUMN */}
              <div className="w-[35%] flex flex-col">
                 <div className="border-b border-black flex h-7 items-center">
                   <div className="w-[60%] border-r border-black p-1 pl-2 text-[11px] font-bold">Freight fixed</div>
                   <div className="w-[40%] text-right text-[11px]"><input value={0} readOnly className="w-full text-right outline-none bg-transparent px-2 font-mono"/></div>
                 </div>
                 <div className="border-b border-black flex h-7 items-center">
                   <div className="w-[60%] border-r border-black p-1 pl-2 text-[11px]">Advance paid</div>
                   <div className="w-[40%] text-right text-[11px]"><input value={0} readOnly className="w-full text-right outline-none bg-transparent px-2 font-mono"/></div>
                 </div>
                 <div className="border-b border-black flex h-7 items-center">
                   <div className="w-[60%] border-r border-black p-1 pl-2 text-[11px]">Balance topay</div>
                   <div className="w-[40%] text-right text-[11px]"><input value={0} readOnly className="w-full text-right outline-none bg-transparent px-2 font-mono"/></div>
                 </div>
                 <div className="flex-grow border-b border-black flex p-2">
                   <div className="w-full text-[10px] font-bold">
                      Freight Remarks:
                      <textarea rows="2" value={freight.freightNote} onChange={e => setFreight({...freight, freightNote: e.target.value})} className="w-full outline-none bg-yellow-50 border border-yellow-200 mt-1 p-1 resize-none font-normal" placeholder="Remarks..." />
                   </div>
                 </div>
                 <div className="flex h-8 bg-slate-100 items-center">
                   <div className="w-[60%] border-r border-black p-1 pl-2 text-[12px] font-black uppercase">Total To pay</div>
                   <div className="w-[40%] text-right text-[14px] font-black p-1 pr-2">0.00</div>
                 </div>
              </div>
            </div>

            {/* ROW 5: NOTE */}
            <div className="border-b border-black p-1 text-center font-bold text-[10px]">
               Note : WE ARE NOT RESPONSIBLE FOR FIRE, THEFT, LEAKAGE, DAMAGE & BREAKAGE
            </div>

            {/* ROW 6: FOOTER DATA */}
            <div className="flex">
              <div className="w-[65%] border-r border-black p-3 flex flex-col gap-2 text-[11px] font-bold">
                 <div className="grid grid-cols-[80px_1fr] items-center">
                   <span>Bill No</span>
                   <div className="flex gap-1 items-center">: <input placeholder="Invoice No" value={partyDetails.invoiceNumber} onChange={e => setPartyDetails({...partyDetails, invoiceNumber: e.target.value})} className="w-full outline-none bg-yellow-50 px-1 border border-yellow-200 py-0.5 uppercase" /></div>
                 </div>
                 <div className="grid grid-cols-[80px_1fr] items-center">
                   <span>Bill Date</span>
                   <div className="flex gap-1 items-center">: <input type="date" value={partyDetails.invoiceDate} onChange={e => setPartyDetails({...partyDetails, invoiceDate: e.target.value})} className="w-full outline-none bg-yellow-50 px-1 border border-yellow-200 py-0.5 uppercase text-[10px]" /></div>
                 </div>
                 <div className="grid grid-cols-[80px_1fr] items-center">
                   <span>Goods value</span>
                   <div className="flex gap-1 items-center">: <input type="number" placeholder="Value ₹" value={partyDetails.invoiceValue} onChange={e => setPartyDetails({...partyDetails, invoiceValue: e.target.value})} className="w-full outline-none bg-yellow-50 px-1 border border-yellow-200 py-0.5" /></div>
                 </div>
                 <div className="grid grid-cols-[80px_1fr] items-center">
                   <span>Lorry No</span>
                   <div className="flex gap-1 text-slate-400 font-normal">: Lorry assigned at Dispatch</div>
                 </div>
              </div>
              <div className="w-[35%] p-2 flex flex-col justify-between font-bold text-[11px] relative">
                 <div className="text-right mt-1">For {gcDetails.companyMode === 'A' ? 'A.P. Roadlines' : 'The Bell Lorry Agencies'}</div>
                 <div className="text-right mt-12 mb-1 text-slate-400 font-normal">Authorized signature</div>
              </div>
            </div>

          </div>

          {/* --- ABSOLUTE BOTTOM --- */}
          <div className="flex justify-between text-[10px] font-bold mt-1 text-slate-700">
            <span>Subject to Sivakasi juristiction</span>
          </div>

        </div>
      </div>
      
      <PrintCopiesModal isOpen={showPrintModal} onClose={() => setShowPrintModal(false)} onConfirm={(copies) => { setShowPrintModal(false); window.open(\`/print/gc/\${searchEditGc}?copies=\${copies.join(',')}\`, '_blank'); }} />
      <ScannerModal isOpen={isScannerOpen} onClose={() => setIsScannerOpen(false)} onScan={(txt) => { setEwayBillNo(txt); setIsScannerOpen(false); }} />
    </div>
  );`;

content = content.replace(returnRegex, newReturn);

fs.writeFileSync(file, content);
console.log('Applied WYSIWYG Print layout to GcEntry.jsx');
