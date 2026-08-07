import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api } from '../api';
import { generateGdmPdfBlob } from '../utils/gdmPdfGenerator';
import { Button } from '../components/ui/Button';

export default function CewbPrint() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [pdfUrl, setPdfUrl] = useState('');
  const [error, setError] = useState('');
  const [hardwareStatus, setHardwareStatus] = useState('');

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [gdmData, unitsRes] = await Promise.all([
          api.get(`/gdms/${id}`),
          api.get('/units').catch(() => [])
        ]);
        
        let allUnitOptions = [];
        if (unitsRes && unitsRes.length > 0) {
          allUnitOptions = unitsRes.map(u => ({
            label: u.description,
            code: u.code,
            category: u.category
          }));
        }

        const gdmArray = Array.isArray(gdmData) ? gdmData : [gdmData];
        
        const dataUrl = await generateGdmPdfBlob(gdmArray, allUnitOptions, 'cewb');
        setPdfUrl(dataUrl);
      } catch (err) {
        setError('Failed to generate CEWB PDF.');
      }
    };
    fetchData();
  }, [id]);

  if (error) return <div className="p-10 text-rose-500 font-bold">{error}</div>;
  if (!pdfUrl) return (
    <div className="h-screen w-full flex items-center justify-center bg-slate-800 flex-col gap-4">
      <div className="animate-spin rounded-full h-16 w-16 border-b-4 border-indigo-500"></div>
      <div className="text-slate-400 font-bold tracking-widest animate-pulse">GENERATING CEWB PDF...</div>
    </div>
  );

  const handleNativeDownload = () => {
    const link = document.createElement('a');
    link.href = pdfUrl;
    link.download = `CEWB_${id || 'Print'}.pdf`;
    link.click();
  };

  const handleSilentHardwarePrint = async () => {
    setHardwareStatus('Generating PDF...');
    try {
      const res = await fetch(pdfUrl);
      const blob = await res.blob();
      
      setHardwareStatus('Connecting to Agent...');
      const formData = new FormData();
      formData.append('pdf', blob, `CEWB_${id || 'Print'}.pdf`);

      const response = await fetch('http://localhost:8181/print', {
        method: 'POST',
        body: formData,
      });

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
    <div className="h-screen w-full flex flex-col bg-slate-800">
      <div className="flex justify-between items-center p-4 bg-slate-900 text-white shadow-xl z-10 shrink-0">
        <Button variant="custom" 
          onClick={() => navigate(-1)}
          className="bg-slate-700 px-5 py-2.5 rounded-lg font-bold hover:bg-slate-600 transition-colors shadow-lg"
        >
          ← Back
        </Button>
        
        <div className="flex gap-3">
          <Button variant="custom" 
            onClick={handleSilentHardwarePrint}
            disabled={!!hardwareStatus || !pdfUrl}
            className={`${hardwareStatus ? 'bg-amber-400' : 'bg-amber-500 hover:bg-amber-400'} text-slate-900 px-5 py-2.5 rounded-lg font-bold shadow-lg transition-colors flex items-center gap-2`}
          >
            {hardwareStatus || '🖨️ Hardware Print'}
          </Button>
          
          <Button variant="custom" 
            onClick={handleNativeDownload}
            disabled={!pdfUrl}
            className="bg-indigo-500 hover:bg-indigo-400 text-white px-5 py-2.5 rounded-lg font-bold shadow-lg transition-colors flex items-center gap-2"
          >
            📥 Download PDF
          </Button>
        </div>
      </div>
      <div className="flex-1 w-full bg-slate-800 p-8 overflow-hidden flex justify-center">
        <iframe 
          src={pdfUrl} 
          className="w-full max-w-5xl h-full shadow-2xl rounded-lg bg-white"
          title="CEWB PDF Preview"
        />
      </div>
    </div>
  );
}
