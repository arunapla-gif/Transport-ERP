import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { ShieldAlert, Search, Filter, RefreshCw, Calendar, User, GitBranch, Database, FileText } from 'lucide-react';
import toast from 'react-hot-toast';

export default function AuditLogs() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [actionFilter, setActionFilter] = useState('ALL');

  const fetchLogs = async () => {
    try {
      setLoading(true);
      const res = await api.get('/api/audit-logs');
      setLogs(res);
    } catch (err) {
      console.error(err);
      toast.error('Failed to fetch audit logs');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs();
  }, []);

  const filteredLogs = logs.filter(log => {
    const matchesSearch = 
      (log.entity || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (log.entityId || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (log.details || '').toLowerCase().includes(searchTerm.toLowerCase());
      
    const matchesAction = actionFilter === 'ALL' || log.action === actionFilter;
    
    return matchesSearch && matchesAction;
  });

  const getActionColor = (action) => {
    switch(action) {
      case 'CREATE': return 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20';
      case 'UPDATE': return 'bg-amber-500/10 text-amber-600 border-amber-500/20';
      case 'DELETE': return 'bg-rose-500/10 text-rose-600 border-rose-500/20';
      default: return 'bg-slate-500/10 text-slate-600 border-slate-500/20';
    }
  };

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 bg-white p-5 rounded-2xl shadow-sm border border-slate-200">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-xl bg-indigo-50 flex items-center justify-center border border-indigo-100">
            <ShieldAlert className="text-indigo-600 w-6 h-6" />
          </div>
          <div>
            <h1 className="text-xl font-black text-slate-800">System Audit Trails</h1>
            <p className="text-sm text-slate-500 font-medium">Track all creation, updates, and deletions across the ERP</p>
          </div>
        </div>
        
        <div className="flex gap-2 w-full md:w-auto">
          <button 
            onClick={fetchLogs}
            className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg font-bold text-sm transition-colors flex items-center gap-2"
          >
            <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
            Refresh
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-col md:flex-row gap-4 bg-white p-4 rounded-xl shadow-sm border border-slate-200">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-4 h-4" />
          <input
            type="text"
            placeholder="Search by Entity (GC, GDM), ID, or Details..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all font-medium"
          />
        </div>
        <div className="flex items-center gap-2">
          <Filter className="text-slate-400 w-4 h-4" />
          <select
            value={actionFilter}
            onChange={(e) => setActionFilter(e.target.value)}
            className="py-2 pl-3 pr-8 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 font-bold text-slate-700"
          >
            <option value="ALL">All Actions</option>
            <option value="CREATE">Creates</option>
            <option value="UPDATE">Updates</option>
            <option value="DELETE">Deletions</option>
          </select>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50 border-b border-slate-200">
                <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider whitespace-nowrap">Timestamp</th>
                <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider whitespace-nowrap">User</th>
                <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider whitespace-nowrap">Action</th>
                <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider whitespace-nowrap">Module / Record</th>
                <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider w-full">Details</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan="5" className="p-8 text-center text-slate-400">
                    <div className="flex justify-center mb-2">
                      <RefreshCw className="w-6 h-6 animate-spin text-indigo-400" />
                    </div>
                    Loading audit trails...
                  </td>
                </tr>
              ) : filteredLogs.length === 0 ? (
                <tr>
                  <td colSpan="5" className="p-8 text-center text-slate-400 font-medium">
                    No logs found matching your filters.
                  </td>
                </tr>
              ) : (
                filteredLogs.map((log) => (
                  <tr key={log.id} className="hover:bg-slate-50/50 transition-colors">
                    <td className="p-4 whitespace-nowrap">
                      <div className="flex items-center gap-2 text-sm text-slate-600 font-medium">
                        <Calendar size={14} className="text-slate-400" />
                        {new Date(log.createdAt).toLocaleString('en-IN', {
                          day: '2-digit', month: 'short', year: 'numeric',
                          hour: '2-digit', minute: '2-digit', hour12: true
                        })}
                      </div>
                    </td>
                    <td className="p-4 whitespace-nowrap">
                      <div className="flex flex-col gap-1">
                        <div className="flex items-center gap-1.5 text-sm font-bold text-slate-700">
                          <User size={14} className={log.userRole === 'admin' ? 'text-indigo-500' : 'text-emerald-500'} />
                          {log.userRole.toUpperCase()}
                        </div>
                        <div className="flex items-center gap-1 text-xs font-bold text-slate-500">
                          <GitBranch size={12} />
                          {log.userBranch}
                        </div>
                      </div>
                    </td>
                    <td className="p-4 whitespace-nowrap">
                      <span className={`px-2.5 py-1 rounded-md text-xs font-black border uppercase tracking-wide ${getActionColor(log.action)}`}>
                        {log.action}
                      </span>
                    </td>
                    <td className="p-4 whitespace-nowrap">
                      <div className="flex flex-col gap-1">
                        <div className="flex items-center gap-1.5 text-sm font-bold text-slate-800">
                          <Database size={14} className="text-slate-400" />
                          {log.entity}
                        </div>
                        <div className="flex items-center gap-1 text-xs font-bold text-slate-500">
                          <FileText size={12} />
                          #{log.entityId}
                        </div>
                      </div>
                    </td>
                    <td className="p-4">
                      <div className="text-sm font-medium text-slate-600 bg-slate-50 px-3 py-2 rounded-lg border border-slate-100">
                        {log.details || 'No additional details recorded.'}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
