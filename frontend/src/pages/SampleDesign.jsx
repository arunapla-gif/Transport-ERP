import React, { useState } from 'react';
import { LayoutDashboard, FileBox, FileCheck, Users, Search, Bell, Plus, MoreHorizontal, ArrowRight, ArrowUpRight } from 'lucide-react';

export default function SampleDesign() {
  const [activeTab, setActiveTab] = useState('Overview');

  return (
    <div className="min-h-screen bg-[#F8FAFC] text-slate-900 font-sans selection:bg-blue-100 pb-20">
      
      {/* Sleek Top Navigation */}
      <nav className="bg-white border-b border-slate-200 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-8">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center shadow-inner shadow-blue-500/50">
                <LayoutDashboard size={18} className="text-white" />
              </div>
              <span className="font-bold text-lg tracking-tight text-slate-800">Transport<span className="text-blue-600">ERP</span></span>
            </div>
            
            <div className="hidden md:flex items-center space-x-1">
              {['Overview', 'Consignments', 'Manifests', 'Finances'].map(tab => (
                <button
                  key={tab}
                  onClick={() => setActiveTab(tab)}
                  className={`px-4 py-2 rounded-md text-sm font-medium transition-all ${
                    activeTab === tab 
                      ? 'bg-slate-100 text-slate-900' 
                      : 'text-slate-500 hover:text-slate-700 hover:bg-slate-50'
                  }`}
                >
                  {tab}
                </button>
              ))}
            </div>
          </div>

          <div className="flex items-center gap-4">
            <div className="relative group hidden md:block">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:text-blue-500 transition-colors" />
              <input 
                type="text" 
                placeholder="Search GC, Client, Vehicle..." 
                className="w-64 pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 focus:bg-white transition-all"
              />
            </div>
            <button className="relative p-2 text-slate-400 hover:bg-slate-100 rounded-full transition-colors">
              <Bell size={20} />
              <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-rose-500 rounded-full border-2 border-white"></span>
            </button>
            <div className="w-8 h-8 bg-gradient-to-tr from-blue-600 to-indigo-600 rounded-full border-2 border-white shadow-sm flex items-center justify-center text-white text-xs font-bold cursor-pointer">
              AP
            </div>
          </div>
        </div>
      </nav>

      <main className="max-w-7xl mx-auto px-6 mt-8 space-y-8">
        
        {/* Page Header */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <h1 className="text-3xl font-bold tracking-tight text-slate-900">Dashboard</h1>
            <p className="text-slate-500 text-sm mt-1">Here's what's happening in your logistics network today.</p>
          </div>
          <div className="flex items-center gap-3">
            <button className="px-4 py-2 bg-white border border-slate-200 text-slate-700 text-sm font-medium rounded-lg hover:bg-slate-50 hover:border-slate-300 transition-all shadow-sm">
              Generate Report
            </button>
            <button className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium rounded-lg transition-all shadow-sm shadow-blue-600/20 flex items-center gap-2">
              <Plus size={16} /> New Consignment
            </button>
          </div>
        </div>

        {/* Top Metric Cards (Apple/Stripe Style) */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <MetricCard 
            title="Total Revenue" 
            value="₹24,59,200" 
            trend="+14.5%" 
            subtext="vs last month"
            chartData={[30, 40, 35, 50, 49, 60, 70]}
            chartColor="blue"
          />
          <MetricCard 
            title="Active Consignments" 
            value="1,284" 
            trend="+5.2%" 
            subtext="in transit right now"
            chartData={[60, 55, 65, 50, 70, 68, 80]}
            chartColor="emerald"
          />
          <MetricCard 
            title="Pending Payments" 
            value="₹3,42,100" 
            trend="-2.4%" 
            trendDown 
            subtext="outstanding To-Pay"
            chartData={[80, 75, 60, 65, 50, 45, 40]}
            chartColor="rose"
          />
        </div>

        {/* Data Grid Section */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          
          {/* Main Table Area */}
          <div className="lg:col-span-2 bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
            <div className="px-6 py-5 border-b border-slate-100 flex justify-between items-center bg-slate-50/50">
              <h2 className="text-base font-bold text-slate-800">Recent Consignments</h2>
              <button className="text-blue-600 text-sm font-medium hover:text-blue-700 flex items-center gap-1 group">
                View All <ArrowRight size={14} className="group-hover:translate-x-1 transition-transform" />
              </button>
            </div>
            
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="bg-slate-50 border-b border-slate-100">
                    <th className="px-6 py-3 text-[11px] font-bold text-slate-500 uppercase tracking-wider">GC No.</th>
                    <th className="px-6 py-3 text-[11px] font-bold text-slate-500 uppercase tracking-wider">Consignee</th>
                    <th className="px-6 py-3 text-[11px] font-bold text-slate-500 uppercase tracking-wider">Status</th>
                    <th className="px-6 py-3 text-[11px] font-bold text-slate-500 uppercase tracking-wider">Amount</th>
                    <th className="px-6 py-3 text-[11px] font-bold text-slate-500 uppercase tracking-wider text-right">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {[
                    { id: '5001', name: 'Sri Krishna Fireworks', status: 'In Transit', type: 'warning', amt: '₹14,500' },
                    { id: '5002', name: 'Standard Traders', status: 'Delivered', type: 'success', amt: '₹8,200' },
                    { id: '5003', name: 'Global Logistics', status: 'Created', type: 'neutral', amt: '₹22,000' },
                    { id: '5004', name: 'Apex Distributors', status: 'Delivered', type: 'success', amt: '₹5,450' },
                  ].map((row) => (
                    <tr key={row.id} className="hover:bg-slate-50/80 transition-colors cursor-pointer group">
                      <td className="px-6 py-4 text-sm font-bold text-slate-800">#{row.id}</td>
                      <td className="px-6 py-4 text-sm text-slate-600 font-medium">{row.name}</td>
                      <td className="px-6 py-4">
                        <span className={`inline-flex items-center px-2 py-1 rounded-md text-[11px] font-bold uppercase tracking-wide
                          ${row.type === 'success' ? 'bg-emerald-100 text-emerald-700' : 
                            row.type === 'warning' ? 'bg-amber-100 text-amber-700' : 
                            'bg-slate-100 text-slate-600'}`}>
                          {row.status}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-sm font-bold text-slate-700">{row.amt}</td>
                      <td className="px-6 py-4 text-right">
                        <button className="text-slate-400 hover:text-blue-600 transition-colors p-1">
                          <MoreHorizontal size={18} />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {/* Quick Actions & Logistics */}
          <div className="space-y-6">
            
            {/* Quick Actions Card */}
            <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-6">
              <h2 className="text-base font-bold text-slate-800 mb-4">Quick Actions</h2>
              <div className="grid grid-cols-2 gap-3">
                <ActionBtn icon={<FileBox className="text-blue-600" />} label="New GC" />
                <ActionBtn icon={<FileCheck className="text-indigo-600" />} label="New GDM" />
                <ActionBtn icon={<Users className="text-emerald-600" />} label="Add Client" />
                <ActionBtn icon={<Search className="text-rose-600" />} label="Track GC" />
              </div>
            </div>

            {/* Fleet Status */}
            <div className="bg-slate-900 rounded-2xl border border-slate-800 shadow-xl shadow-slate-900/10 p-6 text-white relative overflow-hidden">
              <div className="absolute top-0 right-0 w-32 h-32 bg-blue-500/20 rounded-full blur-3xl" />
              
              <div className="relative z-10">
                <h2 className="text-base font-bold mb-1">Fleet Status</h2>
                <p className="text-slate-400 text-sm mb-6">Real-time vehicle deployment</p>
                
                <div className="space-y-4">
                  <div>
                    <div className="flex justify-between text-sm mb-1.5">
                      <span className="font-medium">On the Road</span>
                      <span className="font-bold">42</span>
                    </div>
                    <div className="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden">
                      <div className="h-full bg-blue-500 rounded-full" style={{ width: '84%' }} />
                    </div>
                  </div>
                  <div>
                    <div className="flex justify-between text-sm mb-1.5">
                      <span className="font-medium">Maintenance</span>
                      <span className="font-bold text-slate-400">3</span>
                    </div>
                    <div className="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden">
                      <div className="h-full bg-amber-500 rounded-full" style={{ width: '6%' }} />
                    </div>
                  </div>
                  <div>
                    <div className="flex justify-between text-sm mb-1.5">
                      <span className="font-medium">Available</span>
                      <span className="font-bold text-slate-400">5</span>
                    </div>
                    <div className="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden">
                      <div className="h-full bg-emerald-500 rounded-full" style={{ width: '10%' }} />
                    </div>
                  </div>
                </div>
              </div>
            </div>

          </div>
        </div>
      </main>
    </div>
  );
}

function MetricCard({ title, value, trend, subtext, chartData, chartColor, trendDown = false }) {
  const colorMap = {
    blue: 'fill-blue-500/10 stroke-blue-500',
    emerald: 'fill-emerald-500/10 stroke-emerald-500',
    rose: 'fill-rose-500/10 stroke-rose-500',
  };

  const points = chartData.map((val, i) => `${i * 20},${60 - (val / 100 * 60)}`).join(' ');

  return (
    <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm hover:shadow-md hover:border-slate-300 transition-all group cursor-pointer">
      <div className="flex justify-between items-start mb-4">
        <div>
          <h3 className="text-sm font-bold tracking-wider text-slate-500 uppercase">{title}</h3>
          <p className="text-2xl font-black text-slate-900 mt-1 tracking-tight">{value}</p>
        </div>
        <div className={`px-2 py-1 rounded-md text-xs font-bold ${trendDown ? 'bg-rose-50 text-rose-600' : 'bg-emerald-50 text-emerald-600'}`}>
          {trend}
        </div>
      </div>
      
      <div className="h-12 w-full mt-4 relative opacity-60 group-hover:opacity-100 transition-opacity">
        <svg viewBox="0 0 120 60" preserveAspectRatio="none" className="w-full h-full overflow-visible">
          <polyline 
            points={`0,60 ${points} 120,60`}
            className={colorMap[chartColor].split(' ')[0]}
          />
          <polyline 
            points={points}
            fill="none"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            className={colorMap[chartColor].split(' ')[1]}
          />
        </svg>
      </div>
      <p className="text-xs text-slate-400 mt-2 font-medium">{subtext}</p>
    </div>
  );
}

function ActionBtn({ icon, label }) {
  return (
    <button className="flex flex-col items-center justify-center gap-3 p-4 rounded-xl border border-slate-100 bg-slate-50 hover:bg-white hover:border-slate-300 hover:shadow-sm transition-all group">
      <div className="p-2 bg-white rounded-lg shadow-sm border border-slate-100 group-hover:scale-110 transition-transform duration-300">
        {icon}
      </div>
      <span className="text-xs font-bold text-slate-600">{label}</span>
    </button>
  );
}
