import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api } from '../api';
import { generateGdmPdfBlob } from '../utils/gdmPdfGenerator';

export default function GdmPrint() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [pdfUrl, setPdfUrl] = useState('');
  const [error, setError] = useState('');

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
        
        const dataUrl = await generateGdmPdfBlob(gdmArray, allUnitOptions);
        setPdfUrl(dataUrl);
      } catch (err) {
        setError('Failed to generate GDM PDF.');
      }
    };
    fetchData();
  }, [id]);

  if (error) return <div className="p-10 text-rose-500 font-bold">{error}</div>;
  if (!pdfUrl) return (
    <div className="h-screen w-full flex items-center justify-center bg-slate-800 flex-col gap-4">
      <div className="animate-spin rounded-full h-16 w-16 border-b-4 border-indigo-500"></div>
      <div className="text-slate-400 font-bold tracking-widest animate-pulse">GENERATING GDM PDF...</div>
    </div>
  );

  return (
    <div className="h-screen w-full flex flex-col bg-slate-800">
      <div className="flex justify-between items-center p-4 bg-slate-900 text-white shadow-xl z-10">
        <button 
          onClick={() => navigate(-1)}
          className="bg-slate-700 px-4 py-2 rounded-lg font-bold hover:bg-slate-600 transition-colors shadow-lg"
        >
          ← Back
        </button>
        <h1 className="text-xl font-bold tracking-widest text-slate-300 font-serif">GDM PRINT HUB</h1>
        <div className="w-20"></div>
      </div>
      <div className="flex-1 w-full p-2 lg:p-6 overflow-hidden">
        <iframe 
          src={pdfUrl} 
          className="w-full h-full rounded-xl shadow-2xl border-4 border-slate-700 bg-slate-300"
          title="GDM Document"
        />
      </div>
    </div>
  );
}
