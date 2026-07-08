import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api } from '../api';
import { downloadGcPdf, generateGcPdfBlob } from '../utils/pdfGenerator';

export default function GcPrint() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [gcs, setGcs] = useState([]);
  const [error, setError] = useState('');
  const [hardwareStatus, setHardwareStatus] = useState('');
  const [pdfUrl, setPdfUrl] = useState('');
  const [debugStatus, setDebugStatus] = useState('Initializing...');

  // Extract copies from URL or default to CONSIGNOR COPY
  const queryParams = new URLSearchParams(window.location.search);
  const copiesParam = queryParams.get('copies');
  const mode = queryParams.get('mode');
  const selectedCopies = copiesParam ? copiesParam.split(',') : ['CONSIGNOR COPY'];

  useEffect(() => {
    let currentUrl = '';
    let isCancelled = false;

    const fetchGc = async () => {
      try {
        setDebugStatus(`Fetching ${mode === 'gdm' ? 'GDM' : 'GC'} data...`);
        
        let gcArray = [];
        if (mode === 'gdm') {
          const gdmData = await api.get(`/gdms/${id}`);
          const gdmArray = Array.isArray(gdmData) ? gdmData : [gdmData];
          gcArray = gdmArray.flatMap(gdm => gdm.gcs || []);
          if (gcArray.length === 0) throw new Error("No GCs found in this GDM.");
        } else {
          const gcData = await api.get(`/gcs/${id}`); 
          gcArray = Array.isArray(gcData) ? gcData : [gcData];
        }
        
        if (isCancelled) return;
        setGcs(gcArray);
        
        setDebugStatus('Formatting PDF Layout...');
        // Add a tiny delay to ensure React state commits and fonts load
        await new Promise(r => setTimeout(r, 100));
        
        setDebugStatus('Generating PDF Blob (this might take a few seconds)...');
        const dataUrl = await generateGcPdfBlob(gcArray, selectedCopies);
        
        if (isCancelled) return;
        setDebugStatus('Creating Preview URL...');
        setPdfUrl(dataUrl);
        setDebugStatus('Complete');
      } catch (err) {
        console.error("PDF Generation Error:", err);
        setError(`Failed to generate PDF: ${err.message || 'Unknown error'}`);
      }
    };
    
    fetchGc();

    return () => {
      isCancelled = true;
    };
  }, [id, copiesParam]); // Using copiesParam as string to avoid array dependency issues

  if (error) return <div className="p-10 text-rose-500 font-bold">{error}</div>;
  if (gcs.length === 0) return <div className="p-10 text-slate-500">Loading document...</div>;

  const handleNativeDownload = async () => {
    try {
      downloadGcPdf(gcs, selectedCopies);
    } catch (e) {
      console.error(e);
      alert("Error generating PDF: " + e.message);
    }
  };

  const handleSilentHardwarePrint = async () => {
    setHardwareStatus('Generating PDF...');
    try {
      console.log('Generating PDF DataUrl...');
      const dataUrl = await generateGcPdfBlob(gcs, selectedCopies);
      const res = await fetch(dataUrl);
      const blob = await res.blob();
      console.log('Blob generated:', blob);
      
      setHardwareStatus('Forming Payload...');
      const formData = new FormData();
      formData.append('pdf', blob, `GC_${gcs[0]?.gcNumber || 'Print'}.pdf`);

      setHardwareStatus('Connecting to Agent...');
      console.log('Sending to local print agent...');
      const response = await fetch('http://localhost:8181/print', {
        method: 'POST',
        body: formData,
      });
      console.log('Response received:', response.status);

      setHardwareStatus('Waiting for Printer...');
      if (!response.ok) {
        throw new Error('Local Print Agent is not running or failed to print.');
      }

      setHardwareStatus('Done!');
      alert('Successfully sent to physical printer!');
    } catch (e) {
      console.error(e);
      alert(`Hardware Print Error: Ensure the Local Print Agent is running on this computer! (${e.message})`);
    } finally {
      setTimeout(() => setHardwareStatus(''), 2000);
    }
  };

  return (
    <div className="bg-slate-800 min-h-screen flex flex-col items-center justify-start h-screen overflow-hidden">
      
      {/* Action buttons */}
      <div className="w-full bg-slate-900 p-4 flex justify-between items-center shadow-md shrink-0">
        <button 
          onClick={() => navigate(-1)}
          className="bg-slate-700 text-white px-5 py-2.5 rounded-lg font-bold shadow-lg hover:bg-slate-600 transition-colors"
        >
          ← Back
        </button>

        <div className="flex gap-3">
          <button 
            onClick={handleSilentHardwarePrint}
            disabled={!!hardwareStatus || !pdfUrl}
            className={`${hardwareStatus ? 'bg-amber-400' : 'bg-amber-500 hover:bg-amber-400'} text-slate-900 px-5 py-2.5 rounded-lg font-bold shadow-lg transition-colors flex items-center gap-2`}
          >
            {hardwareStatus ? hardwareStatus : '⚡ Silent Hardware Print'}
          </button>
          <button 
            onClick={handleNativeDownload}
            disabled={!pdfUrl}
            className="bg-emerald-600 text-white px-5 py-2.5 rounded-lg font-bold shadow-lg hover:bg-emerald-500 transition-colors flex items-center gap-2"
          >
            ⬇️ Download PDF
          </button>
        </div>
      </div>

      {/* PDF Viewer */}
      <div className="flex-grow w-full max-w-5xl p-4 flex items-center justify-center">
        {pdfUrl ? (
          <iframe 
            src={pdfUrl} 
            className="w-full h-full rounded-xl shadow-2xl bg-white border border-slate-600"
            title="PDF Preview"
          />
        ) : (
          <div className="flex flex-col items-center gap-4">
            <div className="text-slate-400 font-bold animate-pulse text-lg">
              {debugStatus}
            </div>
            <div className="w-8 h-8 border-4 border-slate-500 border-t-indigo-500 rounded-full animate-spin"></div>
          </div>
        )}
      </div>

    </div>
  );
}
