import React, { useEffect, useState, useRef } from 'react';
import { Html5Qrcode } from 'html5-qrcode';
import { api } from '../../api';
import { X, Camera, QrCode, Type, Loader2 } from 'lucide-react';

export default function ScannerModal({ isOpen, onClose, onScan }) {
  const [mode, setMode] = useState('qr'); // 'qr' or 'text'
  const [error, setError] = useState('');
  const [isScanning, setIsScanning] = useState(false);
  const [ocrProgress, setOcrProgress] = useState('');
  
  const videoRef = useRef(null);
  const streamRef = useRef(null);
  const qrScannerRef = useRef(null);

  useEffect(() => {
    if (!isOpen) return;
    
    let timer;
    setError('');
    setIsScanning(false);
    
    if (mode === 'qr') {
      setIsScanning(true);
      timer = setTimeout(() => {
        const scanner = new Html5Qrcode("reader");
        qrScannerRef.current = scanner;
        
        scanner.start(
          { facingMode: "environment" },
          { fps: 10, qrbox: { width: 250, height: 250 }, aspectRatio: 1.0 },
          (decodedText) => {
            scanner.stop().then(() => {
              setIsScanning(false);
              onScan(decodedText);
            }).catch(err => console.error(err));
          },
          () => {} // Ignore continuous errors
        ).catch((err) => {
          console.error("Camera error:", err);
          setError("Failed to access camera for QR.");
          setIsScanning(false);
        });
      }, 200);
    } else if (mode === 'text') {
      navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } })
        .then(stream => {
          streamRef.current = stream;
          if (videoRef.current) {
            videoRef.current.srcObject = stream;
            videoRef.current.play();
          }
        })
        .catch(err => {
          console.error("Video stream error:", err);
          setError("Failed to access camera for Text Scanner.");
        });
    }

    return () => {
      clearTimeout(timer);
      if (qrScannerRef.current && qrScannerRef.current.isScanning) {
        qrScannerRef.current.stop().catch(console.error);
      }
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(track => track.stop());
      }
    };
  }, [isOpen, mode, onScan]);

  const captureAndScanText = async () => {
    if (!videoRef.current) return;
    
    setIsScanning(true);
    setError('');
    setOcrProgress('Capturing Image...');
    
    const canvas = document.createElement('canvas');
    canvas.width = videoRef.current.videoWidth;
    canvas.height = videoRef.current.videoHeight;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(videoRef.current, 0, 0, canvas.width, canvas.height);
    
    const imageData = canvas.toDataURL('image/jpeg');
    
    setOcrProgress('Running Cloud AI Vision...');
    try {
      const response = await api.post('/scan-ewb', { imageBase64: imageData });
      onScan(response.ewbNo);
    } catch (err) {
      console.error(err);
      setError(err.message || 'AI processing failed. Please try again.');
    } finally {
      setIsScanning(false);
      setOcrProgress('');
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden relative border border-slate-200 flex flex-col max-h-[90vh]">
        
        {/* Header */}
        <div className="bg-slate-800 p-4 text-white flex justify-between items-center">
          <div className="flex items-center gap-2">
            <Camera size={20} className="text-blue-400" />
            <h3 className="font-bold">Scan E-Way Bill</h3>
          </div>
          <button 
            onClick={onClose}
            className="w-8 h-8 flex items-center justify-center bg-slate-700 hover:bg-rose-500 rounded-full transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        {/* Mode Toggle */}
        <div className="flex p-2 bg-slate-100 border-b border-slate-200">
          <button 
            onClick={() => { setMode('qr'); setError(''); }}
            className={`flex-1 flex items-center justify-center gap-2 py-2 text-sm font-bold rounded-lg transition-all ${mode === 'qr' ? 'bg-white text-indigo-700 shadow-sm border border-slate-200' : 'text-slate-500 hover:text-slate-700'}`}
          >
            <QrCode size={16} /> QR / Barcode
          </button>
          <button 
            onClick={() => { setMode('text'); setError(''); }}
            className={`flex-1 flex items-center justify-center gap-2 py-2 text-sm font-bold rounded-lg transition-all ${mode === 'text' ? 'bg-white text-emerald-700 shadow-sm border border-slate-200' : 'text-slate-500 hover:text-slate-700'}`}
          >
            <Type size={16} /> AI Text Reader
          </button>
        </div>

        {/* Scanner Body */}
        <div className="p-4 flex flex-col items-center justify-center bg-slate-50 min-h-[350px] relative overflow-hidden">
          {error && (
            <div className="absolute top-4 left-4 right-4 z-20 text-center text-rose-600 font-medium bg-rose-50 border border-rose-200 p-3 rounded-lg shadow-lg animate-in slide-in-from-top-4">
              {error}
            </div>
          )}

          {mode === 'qr' ? (
            <div className="w-full relative rounded-xl overflow-hidden shadow-inner border border-slate-200 bg-black flex-1 flex flex-col">
              <div id="reader" className="w-full h-full flex-1"></div>
              {isScanning && !error && (
                <div className="absolute top-4 left-0 w-full text-center z-10 pointer-events-none">
                  <span className="bg-black/50 text-white text-xs font-bold px-3 py-1 rounded-full backdrop-blur-md">
                    Position QR inside frame
                  </span>
                </div>
              )}
            </div>
          ) : (
            <div className="w-full relative rounded-xl overflow-hidden shadow-inner border border-slate-200 bg-black flex-1 flex flex-col">
              <video 
                ref={videoRef} 
                className="w-full h-full object-cover" 
                playsInline 
                autoPlay 
                muted
              ></video>
              
              {!isScanning && (
                <div className="absolute bottom-4 left-0 w-full flex justify-center z-10">
                  <button 
                    onClick={captureAndScanText}
                    className="bg-emerald-600 hover:bg-emerald-500 text-white px-6 py-2.5 rounded-full font-bold shadow-[0_4px_12px_rgba(16,185,129,0.4)] transition-all flex items-center gap-2 active:scale-95"
                  >
                    <Camera size={18} /> Read Text
                  </button>
                </div>
              )}
              
              {isScanning && (
                <div className="absolute inset-0 bg-slate-900/80 backdrop-blur-sm flex flex-col items-center justify-center z-20 text-white p-6 text-center">
                  <Loader2 size={32} className="animate-spin text-emerald-400 mb-4" />
                  <p className="font-bold text-lg mb-1">{ocrProgress}</p>
                  <p className="text-xs text-slate-300">Searching for 12-digit E-Way Bill Number...</p>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-3 border-t border-slate-100 bg-white text-center">
          <p className="text-[11px] text-slate-500 font-medium">
            {mode === 'qr' 
              ? "Instantly scans Government QR Codes & Barcodes."
              : "Point camera at the printed 12-digit number and tap Read Text."}
          </p>
        </div>

      </div>
    </div>
  );
}
