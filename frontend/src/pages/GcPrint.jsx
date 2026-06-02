import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api } from '../api';

export default function GcPrint() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [gcs, setGcs] = useState([]);
  const [error, setError] = useState('');

  // Extract copies from URL or default to CONSIGNOR COPY
  const queryParams = new URLSearchParams(window.location.search);
  const copiesParam = queryParams.get('copies');
  const selectedCopies = copiesParam ? copiesParam.split(',') : ['CONSIGNOR COPY'];

  useEffect(() => {
    const fetchGc = async () => {
      try {
        const gcData = await api.get(`/gcs/${id}`); 
        const gcArray = Array.isArray(gcData) ? gcData : [gcData];
        setGcs(gcArray);
        setTimeout(() => {
          window.print();
        }, 500);
      } catch (err) {
        setError('Failed to load GC for printing.');
      }
    };
    fetchGc();
  }, [id]);

  if (error) return <div className="p-10 text-rose-500 font-bold">{error}</div>;
  if (gcs.length === 0) return <div className="p-10 text-slate-500">Loading document...</div>;

  return (
    <div className="bg-slate-200 min-h-screen flex flex-col items-center justify-start print:bg-white print:min-h-0 print:block">
      {gcs.flatMap((gc, index) => {
        const totalArticles = gc.goods?.reduce((sum, g) => sum + (g.articleCount || 0), 0) || 0;
        const companyName = gc.gcNumber.startsWith('AP-') ? 'AP TRANSPORT' : 'BELL LOGISTICS';
        const companyShort = gc.gcNumber.startsWith('AP-') ? 'AP' : 'BL';
        const copies = selectedCopies;

        return copies.map((copyType, copyIndex) => {
          const isLastTotalItem = index === gcs.length - 1 && copyIndex === copies.length - 1;
          const totalArticles = gc.goods?.reduce((sum, g) => sum + (g.articleCount || 0), 0) || 0;
          const totalFreight = (parseFloat(gc.freightTotal || 0) + 10).toFixed(2); // Added 10 for stat charges

          return (
            <div 
              key={`${gc.id}-${copyIndex}`} 
              className={`w-full flex justify-center p-4 print:p-0 ${!isLastTotalItem ? 'print:break-after-page mb-8 print:mb-0' : ''}`}
            >
              {/* Container dimensions A5 Landscape (210mm x 148mm) */}
              <div 
                className="w-[210mm] min-h-[148mm] bg-white text-black font-sans text-[10px] p-4 relative box-border"
              >
                
                <table className="w-full border-collapse border-2 border-black leading-tight">
                  <tbody>
                    
                    {/* --- ROW 1: HEADER --- */}
                    <tr>
                      <td colSpan="3" className="border border-black p-2 w-[70%]">
                        <div className="flex items-center gap-4 pl-2">
                          <div className="w-14 h-14 bg-black text-white flex items-center justify-center font-bold text-xl rounded transform -skew-x-12">
                            {companyShort}
                          </div>
                          <div>
                            <h1 className="text-[22px] font-black tracking-wider text-black m-0 leading-none mb-1">
                              {companyName}
                            </h1>
                            <div className="text-[8px] leading-[1.2] font-bold text-gray-800">
                              <p>123 LOGISTICS PARK, TRANSPORT ROAD, SIVAKASI - 626123</p>
                              <p>Ph: 9876543210 | GSTIN: 33BBBBB0000B1Z1</p>
                            </div>
                          </div>
                        </div>
                      </td>
                      <td colSpan="2" className="border border-black p-2 w-[30%] align-top">
                        <div className="flex flex-col h-full justify-between font-bold text-[9px]">
                          <div className="text-center font-black text-[11px] uppercase border-b border-black pb-1 mb-1">{copyType}</div>
                          <div className="flex justify-between">
                            <span>G.C. Note No.</span>
                            <span className="font-black text-xs">{gc.gcNumber}</span>
                          </div>
                          <div className="flex justify-between">
                            <span>Date</span>
                            <span className="font-black">{new Date(gc.date).toLocaleDateString('en-GB')}</span>
                          </div>
                        </div>
                      </td>
                    </tr>

                    {/* --- ROW 2: LORRY OWNER --- */}
                    <tr>
                      <td colSpan="3" className="border border-black p-1.5 pl-3 font-bold text-[9px]">
                        Lorry Owner Address : {gc.vehicle?.vehicleNumber || 'TN 95 B 7869'}
                      </td>
                      <td colSpan="2" className="border border-black p-1.5 bg-gray-50/50 font-black text-center text-[10px] tracking-wider uppercase">
                        AT OWNER'S RISK
                      </td>
                    </tr>

                    {/* --- ROW 3: CONSIGNOR, FREIGHT, CONSIGNEE --- */}
                    <tr>
                      <td colSpan="2" className="border border-black p-2 w-[40%] align-top">
                        <div className="font-bold underline mb-1">Consignor M/s :</div>
                        <div className="text-[10px] font-black uppercase">{gc.consignor?.name || 'N/A'}</div>
                        <div className="text-[8px] leading-tight">{gc.consignor?.address} {gc.consignor?.city}</div>
                        <div className="text-[8px] font-bold mt-2">GSTIN: {gc.consignor?.gstin}</div>
                      </td>
                      <td colSpan="1" className="border border-black p-2 w-[20%] align-middle text-center bg-gray-50/50">
                        <div className="font-bold underline mb-1">FREIGHT</div>
                        <div className="text-[9px] font-bold">Charged To</div>
                        <div className="font-black text-[11px] uppercase mt-1">{gc.consignee?.city || 'SIVAKASI'}</div>
                      </td>
                      <td colSpan="2" className="border border-black p-2 w-[40%] align-top">
                        <div className="font-bold underline mb-1">Consignee M/s :</div>
                        <div className="text-[10px] font-black uppercase">{gc.consignee?.name || 'N/A'}</div>
                        <div className="text-[8px] leading-tight">{gc.consignee?.address} {gc.consignee?.city}</div>
                        <div className="text-[8px] font-bold mt-2">GSTIN: {gc.consignee?.gstin}</div>
                      </td>
                    </tr>

                    {/* --- ROW 4: SUB-HEADERS FOR ARTICLES --- */}
                    <tr className="text-center font-bold text-[9px]">
                      <td className="border border-black p-1.5 w-[15%]">No. of Articles</td>
                      <td colSpan="2" className="border border-black p-1.5 w-[50%]">Description</td>
                      <td className="border border-black p-1.5 w-[20%] text-left pl-2">Charges Head</td>
                      <td className="border border-black p-1.5 w-[15%] text-right pr-2">Amount</td>
                    </tr>

                    {/* --- ROW 5: MAIN CONTENT (ARTICLES & CHARGES) --- */}
                    <tr className="align-top">
                      <td className="border border-black p-2 text-center align-middle font-black text-xl">
                        {totalArticles}
                      </td>
                      
                      <td colSpan="2" className="border border-black p-2 align-top">
                        <div className="font-bold italic text-[9px] mb-2">Said to Contain</div>
                        {gc.goods?.map((g, i) => (
                          <div key={i} className="font-bold text-[10px] uppercase mb-1">
                            {g.articleCount} {g.units} OF {g.description}
                          </div>
                        ))}
                      </td>

                      <td colSpan="2" className="border border-black p-0 m-0 align-top">
                        {/* Nested table to perfectly align charges */}
                        <table className="w-full h-full border-collapse">
                          <tbody className="text-[9px] font-bold">
                            <tr>
                              <td className="p-1.5 border-b border-black border-r pl-2">Freight Fixed</td>
                              <td className="p-1.5 border-b border-black text-right pr-2">{gc.freightFixed === 'Yes' ? gc.freightRate || '0.00' : '0.00'}</td>
                            </tr>
                            <tr>
                              <td className="p-1.5 border-b border-black border-r pl-2">Advance Paid</td>
                              <td className="p-1.5 border-b border-black text-right pr-2">{gc.advancePaid || 'Nil'}</td>
                            </tr>
                            <tr>
                              <td className="p-1.5 border-b border-black border-r pl-2">Balance</td>
                              <td className="p-1.5 border-b border-black text-right pr-2">{gc.balanceFreight || '0.00'}</td>
                            </tr>
                            <tr>
                              <td className="p-1.5 border-b border-black border-r pl-2">Statistical Chg</td>
                              <td className="p-1.5 border-b border-black text-right pr-2">10.00</td>
                            </tr>
                            <tr className="bg-gray-100">
                              <td className="p-2 font-black text-[11px] border-r border-black pl-2">Total To-Pay</td>
                              <td className="p-2 font-black text-[11px] text-right pr-2">{totalFreight}</td>
                            </tr>
                          </tbody>
                        </table>
                      </td>
                    </tr>

                    {/* --- ROW 6: FOOTER --- */}
                    <tr>
                      <td colSpan="3" className="border border-black p-2 align-top">
                        <div className="flex justify-between font-bold text-[9px] mb-2">
                          <span><b>Inv No:</b> {gc.invoiceNumber || '-'}</span>
                          <span><b>Inv Date:</b> {gc.invoiceDate ? new Date(gc.invoiceDate).toLocaleDateString('en-GB') : '-'}</span>
                          <span><b>Value:</b> Rs. {gc.invoiceValue ? gc.invoiceValue.toFixed(2) : '-'}</span>
                        </div>
                        <div className="flex gap-1 text-[10px] font-bold">
                          <span>{gc.freightType === 'To Pay' ? 'TO PAY' : 'PAID'} Rupees :</span>
                          <span className="font-black uppercase">{parseFloat(totalFreight).toFixed(0)} Only</span>
                        </div>
                      </td>
                      <td colSpan="2" className="border border-black p-2 text-center flex flex-col justify-between min-h-[50px]">
                        <span className="text-[9px] font-bold">For {companyName}</span>
                        <span className="italic mt-6 font-normal text-[8px]">(Authorized Signatory)</span>
                      </td>
                    </tr>

                  </tbody>
                </table>
              </div>
            </div>
          );
        });
      })}

      {/* Action buttons (hidden on print) */}
      <button 
        onClick={() => navigate(-1)}
        className="fixed top-4 left-4 bg-slate-800 text-white px-5 py-2.5 rounded-lg font-bold shadow-lg print:hidden hover:bg-slate-700 transition-colors"
      >
        ← Back
      </button>

      <button 
        onClick={() => window.print()}
        className="fixed top-4 right-4 bg-indigo-600 text-white px-5 py-2.5 rounded-lg font-bold shadow-lg print:hidden hover:bg-indigo-500 transition-colors flex items-center gap-2"
      >
        🖨️ Print Receipt
      </button>

    </div>
  );
}
