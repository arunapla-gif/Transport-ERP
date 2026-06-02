import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { PackageOpen, Volume2, Loader2, ListFilter } from 'lucide-react';

export default function GodownPlanner() {
  const [stock, setStock] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [aiResponse, setAiResponse] = useState('');
  const [visualFilter, setVisualFilter] = useState([]);

  useEffect(() => {
    fetchStock();
  }, []);

  const fetchStock = async () => {
    try {
      setLoading(true);
      const res = await api.get('/godown-stock');
      setStock(Array.isArray(res) ? res : []);
    } catch (err) {
      setError('கோடவுன் டேட்டா எடுக்க முடியவில்லை (Failed to load godown data)');
    } finally {
      setLoading(false);
    }
  };

  const handleSpeak = () => {
    if (!('speechSynthesis' in window)) {
      alert("Your browser does not support Voice. (உங்க போன்ல வாய்ஸ் சப்போர்ட் இல்ல)");
      return;
    }

    // Stop any ongoing speech
    window.speechSynthesis.cancel();

    if (stock.length === 0) {
      const msg = new SpeechSynthesisUtterance("கோடவுனில் எந்த சரக்கும் இல்லை."); // "No stock in godown"
      msg.lang = 'ta-IN';
      window.speechSynthesis.speak(msg);
      return;
    }

    setIsSpeaking(true);

    // Build the Tamil sentence
    let speechText = "ஐயா வணக்கம். இன்று கோடவுனில் உள்ள சரக்கு விவரங்கள். ";
    
    stock.forEach(item => {
      // Clean up English name for Tamil pronunciation slightly (if needed)
      const name = item.consigneeName;
      const parcels = item.totalArticles > 0 ? `${item.totalArticles} பார்சல், ` : '';
      const weight = item.totalWeight > 0 ? `${item.totalWeight} கிலோ ` : '';
      const gcs = `${item.totalGCs} பில் `;
      
      speechText += `${name}க்கு, ${parcels} ${weight} சரக்கு இருக்கு. மொத்தம் ${gcs}. `;
    });

    speechText += "நன்றி.";

    const utterance = new SpeechSynthesisUtterance(speechText);
    utterance.lang = 'ta-IN';
    utterance.rate = 0.9; // Slightly slower for clarity
    utterance.pitch = 1.0;

    utterance.onend = () => {
      setIsSpeaking(false);
    };
    
    utterance.onerror = (e) => {
      console.error("Speech Error", e);
      setIsSpeaking(false);
    };

    window.speechSynthesis.speak(utterance);
  };

  const [mediaRecorder, setMediaRecorder] = useState(null);
  const [isRecording, setIsRecording] = useState(false);

  const toggleRecording = async () => {
    if (isRecording) {
      stopRecording();
      return;
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const recorder = new MediaRecorder(stream);
      const chunks = [];
      
      recorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunks.push(e.data);
      };
      
      recorder.onstop = async () => {
        const audioBlob = new Blob(chunks, { type: recorder.mimeType });
        processGeminiAudio(audioBlob, recorder.mimeType);
        stream.getTracks().forEach(track => track.stop()); // close mic
      };
      
      setMediaRecorder(recorder);
      recorder.start();
      setIsListening(true);
      setIsRecording(true);
      setTranscript('கேட்கிறது... (Recording: Click again to Stop & Send)');
      setAiResponse('');
      window.speechSynthesis.cancel();
      
    } catch (err) {
      console.error("Mic error:", err);
      alert("Microphone permission denied or not supported.");
    }
  };

  const stopRecording = () => {
    if (mediaRecorder && mediaRecorder.state !== 'inactive') {
      mediaRecorder.stop();
      setIsRecording(false);
      setTranscript('Processing with AI...');
    }
  };

  const processGeminiAudio = async (blob, mimeType) => {
    try {
      // Convert Blob to Base64
      const reader = new FileReader();
      reader.readAsDataURL(blob);
      reader.onloadend = async () => {
        const base64Audio = reader.result;
        
        try {
          const res = await api.post('/godown-ai', {
            audioData: base64Audio,
            mimeType: mimeType || 'audio/webm',
            stockContext: stock
          });
          
          setTranscript('கேள்வி கேட்கப்பட்டது (Question recorded)');
          setAiResponse(res.reply);
          
          if (res.filteredConsignees && res.filteredConsignees.length > 0) {
            setVisualFilter(res.filteredConsignees);
          } else {
            setVisualFilter([]);
          }

          if (res.audioBase64) {
            playPremiumVoice(res.audioBase64, res.reply);
          } else {
            speakAI(res.reply);
          }
        } catch (apiErr) {
           console.error(apiErr);
           setTranscript('Error processing AI request. Please try again.');
        }
      };
    } catch (error) {
      console.error("Audio processing failed:", error);
      setIsListening(false);
    }
  };

  const playPremiumVoice = (base64String, fallbackText) => {
    try {
      const audio = new Audio("data:audio/mp3;base64," + base64String);
      setIsSpeaking(true);
      setIsListening(false);
      audio.onended = () => setIsSpeaking(false);
      
      const playPromise = audio.play();
      if (playPromise !== undefined) {
        playPromise.catch(error => {
          console.error("Browser blocked premium audio:", error);
          setIsSpeaking(false);
          // Fallback to robotic voice if premium gets blocked
          speakAI(fallbackText);
        });
      }
    } catch (err) {
      console.error("Premium Audio Playback failed:", err);
      setIsSpeaking(false);
      speakAI(fallbackText);
    }
  };

  const speakAI = (replyText) => {
    const utterance = new SpeechSynthesisUtterance(replyText);
    utterance.lang = 'ta-IN';
    utterance.rate = 0.9;
    
    setIsSpeaking(true);
    setIsListening(false);
    utterance.onend = () => setIsSpeaking(false);
    window.speechSynthesis.speak(utterance);
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6 pb-20 pt-4 px-4" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      <div className="flex flex-col items-center text-center space-y-2 mb-8">
        <div className="bg-amber-100 text-amber-700 p-4 rounded-full shadow-sm mb-2">
          <PackageOpen size={48} />
        </div>
        <h1 className="text-3xl font-black text-slate-800 tracking-tight">கோடவுன் இருப்பு</h1>
        <p className="text-lg font-bold text-slate-500">Godown Stock Planner</p>
      </div>

      {error && <div className="bg-rose-50 text-rose-600 p-4 rounded-xl text-center font-bold border border-rose-200">{error}</div>}

      {/* Voice Controls */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-8">
        {/* Basic Reading Button */}
        <button 
          onClick={handleSpeak}
          disabled={isSpeaking || loading || isListening}
          className={`w-full py-6 rounded-3xl font-black text-xl shadow-[0_8px_30px_rgba(245,158,11,0.3)] transition-all flex flex-col items-center justify-center gap-3 ${isSpeaking && !aiResponse ? 'bg-rose-500 text-white animate-pulse shadow-[0_8px_30px_rgba(243,64,121,0.5)]' : 'bg-amber-500 hover:bg-amber-400 text-white'}`}
        >
          <Volume2 size={36} />
          முழு விவரம் படி (Read All)
        </button>

        {/* AI Assistant Mic Button */}
        <button 
          onClick={toggleRecording}
          disabled={isSpeaking || (isListening && !isRecording)}
          className={`w-full py-6 rounded-3xl font-black text-xl shadow-[0_8px_30px_rgba(14,165,233,0.3)] transition-all flex flex-col items-center justify-center gap-3 select-none ${isRecording ? 'bg-rose-600 text-white animate-pulse shadow-[0_8px_30px_rgba(225,29,72,0.5)]' : isListening ? 'bg-sky-600 text-white animate-bounce' : 'bg-sky-500 hover:bg-sky-400 text-white'}`}
        >
          <Volume2 size={36} />
          {isRecording ? 'பேசுங்கள் (Click to Stop & Send)...' : isListening ? 'Processing AI...' : 'Click to Ask (கேள்வி கேள்)'}
        </button>
      </div>

      {/* Trial AI Output Box */}
      {(transcript || aiResponse) && (
        <div className="bg-sky-50 border border-sky-200 rounded-3xl p-6 shadow-inner text-center mt-4">
           {transcript && (
             <div className="text-slate-500 text-sm font-bold mb-2">நீங்கள் கேட்டது (You asked): <br/><span className="text-slate-800 text-lg">"{transcript}"</span></div>
           )}
           {aiResponse && (
             <div className="text-sky-700 text-sm font-bold mt-4">AI பதில் (AI Reply): <br/><span className="text-sky-900 text-xl font-black">"{aiResponse}"</span></div>
           )}
        </div>
      )}

      {/* Clear Filter Button if active */}
      {visualFilter.length > 0 && (
        <div className="flex justify-center mt-2 mb-2">
          <button 
            onClick={() => setVisualFilter([])}
            className="px-6 py-2 bg-slate-200 hover:bg-slate-300 text-slate-700 font-bold rounded-full text-sm transition-all shadow-sm"
          >
            அனைத்து சரக்குகளையும் காட்டு (Show All Stock)
          </button>
        </div>
      )}

      {/* Simple Big Table for Reading */}
      <div className="bg-white rounded-3xl shadow-lg border border-slate-200/60 overflow-hidden mt-8">
        <div className="p-5 border-b border-slate-100 bg-slate-50/50 flex items-center justify-center gap-2">
          <ListFilter size={24} className="text-slate-400" />
          <h2 className="text-xl font-black text-slate-800">சரக்கு பட்டியல் (Stock List)</h2>
        </div>
        
        {loading ? (
          <div className="p-10 flex justify-center text-slate-400"><Loader2 className="animate-spin" size={32} /></div>
        ) : stock.length === 0 ? (
          <div className="p-10 text-center">
            <h3 className="text-2xl font-black text-slate-400">கோடவுனில் சரக்கு இல்லை</h3>
            <p className="text-slate-400 mt-2">No pending stock.</p>
          </div>
        ) : (
          <div className="divide-y divide-slate-100">
            {stock
              .filter(s => visualFilter.length === 0 || visualFilter.includes(s.consigneeName))
              .map((item, idx) => (
              <div key={idx} className="p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div>
                  <h3 className="text-2xl font-black text-slate-800 uppercase leading-tight">
                    {item.consigneeName}
                  </h3>
                  <p className="text-slate-500 font-bold mt-1 text-sm flex gap-2">
                    <span className="bg-slate-100 px-2 py-0.5 rounded text-slate-600">{item.totalGCs} GCs</span>
                  </p>
                </div>
                
                <div className="flex items-end sm:items-center gap-4">
                  {item.totalArticles > 0 && (
                    <div className="text-center bg-sky-50 px-4 py-2 rounded-xl">
                      <div className="text-[10px] font-black text-sky-600 uppercase">பார்சல்</div>
                      <div className="text-xl font-black text-sky-800">{item.totalArticles}</div>
                    </div>
                  )}
                  {item.totalWeight > 0 && (
                    <div className="text-center bg-emerald-50 px-4 py-2 rounded-xl">
                      <div className="text-[10px] font-black text-emerald-600 uppercase">கிலோ (KG)</div>
                      <div className="text-xl font-black text-emerald-800">{item.totalWeight}</div>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
