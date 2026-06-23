import React, { useState, useEffect } from 'react';
import { X, MapPin, Navigation, Clock, AlertTriangle } from 'lucide-react';
import { MapContainer, TileLayer, Marker, Popup, Polyline } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import { api } from '../../api';

// Fix for default Leaflet icon paths in React
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

// Custom Icon for toll plazas
const tollIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-violet.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

// Custom Icon for current/latest position
const currentIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});


export function TrackingModal({ isOpen, onClose, vehicleNumber }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [trackingData, setTrackingData] = useState([]);

  useEffect(() => {
    if (isOpen && vehicleNumber) {
      fetchTrackingData();
    } else {
      setTrackingData([]);
      setError('');
    }
  }, [isOpen, vehicleNumber]);

  const fetchTrackingData = async () => {
    try {
      setLoading(true);
      setError('');
      const res = await api.post('/fastag/track', { vehicleNumber });
      
      if (res.data && res.data.length > 0) {
        // Data comes back ordered. We need to parse coordinates.
        // TollPlazaGeocode is like "25.96846498, 76.25313572"
        const parsedData = res.data.map(item => {
          const coords = item.tollPlazaGeocode ? item.tollPlazaGeocode.split(',') : [0, 0];
          let lat = parseFloat(coords[0]);
          let lng = parseFloat(coords[1]);

          // FASTag API bug: Sometimes it returns [Lng, Lat], sometimes [Lat, Lng].
          // In India, Latitude is ~8 to 38. Longitude is ~68 to 98.
          // If the first number is > 50, they accidentally sent Longitude first.
          if (lat > 50) {
            const temp = lat;
            lat = lng;
            lng = temp;
          }

          return {
            ...item,
            lat,
            lng
          };
        }).filter(item => !isNaN(item.lat) && !isNaN(item.lng));
        
        setTrackingData(parsedData);
      } else {
        setTrackingData([]);
        setError('No recent tracking data found for this vehicle.');
      }
    } catch (err) {
      console.error(err);
      setError('Failed to fetch tracking data. Make sure vehicle number is correct.');
    } finally {
      setLoading(false);
    }
  };

  if (!isOpen) return null;

  // The first item is usually the latest
  const latestLocation = trackingData.length > 0 ? trackingData[0] : null;
  const pathCoordinates = trackingData.map(d => [d.lat, d.lng]);
  // Reverse path for polyline so it draws from oldest to newest if needed, but Leaflet Polyline takes array of points.

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-5xl overflow-hidden flex flex-col h-[85vh]">
        
        {/* Header */}
        <div className="flex items-center justify-between p-5 border-b border-slate-100 bg-slate-50/50">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-600 flex items-center justify-center">
              <Navigation size={20} />
            </div>
            <div>
              <h2 className="text-xl font-black text-slate-800">Live GPS Tracking</h2>
              <p className="text-sm font-bold text-slate-500">Vehicle: {vehicleNumber}</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 rounded-xl text-slate-400 hover:bg-slate-100 transition-colors">
            <X size={24} />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 flex flex-col md:flex-row overflow-hidden bg-white">
          
          {/* Map Area */}
          <div className="flex-1 h-[40vh] md:h-full relative bg-slate-100 border-r border-slate-100">
            {loading ? (
              <div className="absolute inset-0 flex items-center justify-center bg-white/80 z-[400] backdrop-blur-sm">
                <div className="flex flex-col items-center">
                  <div className="w-10 h-10 border-4 border-blue-200 border-t-blue-600 rounded-full animate-spin mb-3"></div>
                  <p className="font-bold text-slate-600">Locating Vehicle...</p>
                </div>
              </div>
            ) : error ? (
              <div className="absolute inset-0 flex items-center justify-center">
                <div className="text-center p-6 max-w-sm">
                  <AlertTriangle size={48} className="mx-auto text-amber-500 mb-4" />
                  <p className="font-bold text-slate-700">{error}</p>
                </div>
              </div>
            ) : trackingData.length > 0 ? (
              <MapContainer 
                center={[latestLocation.lat, latestLocation.lng]} 
                zoom={7} 
                style={{ height: '100%', width: '100%', zIndex: 1 }}
              >
                <TileLayer
                  attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                  url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                />
                
                {/* Draw Route Line */}
                <Polyline positions={pathCoordinates} color="#4f46e5" weight={3} opacity={0.6} dashArray="10, 10" />

                {trackingData.map((data, index) => {
                  const isLatest = index === 0;
                  return (
                    <Marker 
                      key={index} 
                      position={[data.lat, data.lng]}
                      icon={isLatest ? currentIcon : tollIcon}
                    >
                      <Popup>
                        <div className="font-sans">
                          <div className="font-black text-slate-800 text-sm mb-1">{data.tollPlazaName}</div>
                          <div className="text-xs text-slate-500 font-medium mb-1">{data.tollDisplayName}</div>
                          <div className="text-xs font-bold text-blue-600 flex items-center gap-1">
                            <Clock size={12}/>
                            {data.readerReadTime}
                          </div>
                        </div>
                      </Popup>
                    </Marker>
                  );
                })}
              </MapContainer>
            ) : (
              <div className="absolute inset-0 flex items-center justify-center text-slate-400 font-bold">
                No Map Data Available
              </div>
            )}
          </div>

          {/* Timeline Area */}
          <div className="w-full md:w-96 overflow-y-auto bg-white p-5">
            <h3 className="font-black text-slate-800 mb-4 flex items-center gap-2">
              <MapPin size={18} className="text-slate-400"/>
              Last 24 Hours History
            </h3>
            
            {!loading && trackingData.length > 0 && (
              <div className="relative border-l-2 border-slate-100 ml-3 space-y-6">
                {trackingData.map((data, i) => {
                  const isLatest = i === 0;
                  return (
                    <div key={i} className="relative pl-6">
                      <div className={`absolute -left-[9px] top-1 w-4 h-4 rounded-full border-2 border-white ${isLatest ? 'bg-red-500 shadow-[0_0_10px_rgba(239,68,68,0.5)]' : 'bg-slate-300'}`} />
                      <div className={`font-bold text-xs mb-1 ${isLatest ? 'text-red-500' : 'text-slate-400'}`}>
                        {data.readerReadTime}
                      </div>
                      <div className={`font-black text-sm mb-1 ${isLatest ? 'text-slate-800' : 'text-slate-600'}`}>
                        {data.tollPlazaName}
                      </div>
                      <div className="text-xs text-slate-500 leading-snug">
                        {data.tollDisplayName}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
            
            {!loading && trackingData.length === 0 && !error && (
              <div className="text-center text-sm text-slate-500 mt-10">
                Waiting for map data...
              </div>
            )}
          </div>

        </div>
      </div>
    </div>
  );
}
