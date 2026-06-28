import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { Users, Activity, ShieldAlert, Key, UserPlus, LogOut, RefreshCw, Trash2, Edit } from 'lucide-react';
import toast from 'react-hot-toast';

export default function AdminDashboard() {
  const [activeTab, setActiveTab] = useState('users'); // 'users' or 'sessions'
  const [users, setUsers] = useState([]);
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(false);

  // Form state
  const [showModal, setShowModal] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [formData, setFormData] = useState({ username: '', pin: '', role: 'worker', branch: 'MAIN', status: 'Active' });

  const fetchData = async () => {
    setLoading(true);
    try {
      if (activeTab === 'users') {
        const res = await api.get('/admin/users');
        setUsers(res);
      } else {
        const res = await api.get('/admin/sessions');
        setSessions(res);
      }
    } catch (error) {
      toast.error('Failed to fetch data');
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchData();
  }, [activeTab]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (formData.pin.length !== 4) {
      return toast.error('PIN must be exactly 4 digits');
    }
    
    try {
      if (editingId) {
        await api.put(`/admin/users/${editingId}`, formData);
        toast.success('User updated successfully');
      } else {
        await api.post('/admin/users', formData);
        toast.success('User created successfully');
      }
      setShowModal(false);
      fetchData();
    } catch (error) {
      toast.error(error.message || 'Failed to save user');
    }
  };

  const handleEdit = (user) => {
    setFormData({ username: user.username, pin: user.pin, role: user.role, branch: user.branch, status: user.status });
    setEditingId(user.id);
    setShowModal(true);
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this user?')) return;
    try {
      await api.delete(`/admin/users/${id}`);
      toast.success('User deleted');
      fetchData();
    } catch (error) {
      toast.error('Failed to delete user');
    }
  };

  const handleForceLogout = async (id) => {
    if (!window.confirm('Are you sure you want to force logout this session? The user will be immediately kicked out.')) return;
    try {
      await api.delete(`/admin/sessions/${id}`);
      toast.success('Session revoked. User logged out.');
      fetchData();
    } catch (error) {
      toast.error('Failed to revoke session');
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
            <h1 className="text-xl font-black text-slate-800">Admin Controls</h1>
            <p className="text-sm text-slate-500 font-medium">Manage employee access and active system sessions</p>
          </div>
        </div>
        
        <div className="flex gap-2 w-full md:w-auto bg-slate-100 p-1 rounded-xl">
          <button 
            onClick={() => setActiveTab('users')}
            className={`flex-1 md:flex-none px-6 py-2 rounded-lg font-bold text-sm transition-all flex items-center justify-center gap-2 ${activeTab === 'users' ? 'bg-white text-indigo-600 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}
          >
            <Users size={16} /> Users
          </button>
          <button 
            onClick={() => setActiveTab('sessions')}
            className={`flex-1 md:flex-none px-6 py-2 rounded-lg font-bold text-sm transition-all flex items-center justify-center gap-2 ${activeTab === 'sessions' ? 'bg-white text-indigo-600 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}
          >
            <Activity size={16} /> Sessions
          </button>
        </div>
      </div>

      {/* Main Content Area */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        
        {/* TAB: USERS */}
        {activeTab === 'users' && (
          <div>
            <div className="p-4 border-b border-slate-100 flex justify-between items-center bg-slate-50">
              <h2 className="font-black text-slate-700 flex items-center gap-2"><Users size={18} className="text-indigo-500"/> Staff Directory</h2>
              <button 
                onClick={() => {
                  setFormData({ username: '', pin: '', role: 'worker', branch: 'MAIN', status: 'Active' });
                  setEditingId(null);
                  setShowModal(true);
                }}
                className="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg font-bold text-sm flex items-center gap-2 shadow-sm"
              >
                <UserPlus size={16} /> Add Employee
              </button>
            </div>
            
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="bg-slate-50 border-b border-slate-200">
                    <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider">Username</th>
                    <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider">Role & Branch</th>
                    <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider">PIN Code</th>
                    <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider">Status</th>
                    <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {loading ? (
                    <tr><td colSpan="5" className="p-8 text-center text-slate-400"><RefreshCw className="w-6 h-6 animate-spin mx-auto"/></td></tr>
                  ) : users.map(user => (
                    <tr key={user.id} className="hover:bg-slate-50/50">
                      <td className="p-4 font-bold text-slate-800">{user.username}</td>
                      <td className="p-4">
                        <div className="flex gap-2 items-center">
                          <span className={`px-2 py-0.5 rounded text-[10px] font-black uppercase ${user.role === 'admin' ? 'bg-indigo-100 text-indigo-700' : 'bg-emerald-100 text-emerald-700'}`}>{user.role}</span>
                          <span className="px-2 py-0.5 rounded bg-slate-100 text-slate-600 text-[10px] font-black">{user.branch}</span>
                        </div>
                      </td>
                      <td className="p-4 font-mono font-bold text-slate-500">****</td>
                      <td className="p-4">
                        <span className={`px-2.5 py-1 rounded-full text-xs font-bold ${user.status === 'Active' ? 'bg-emerald-50 text-emerald-600' : 'bg-rose-50 text-rose-600'}`}>{user.status}</span>
                      </td>
                      <td className="p-4 text-right">
                        <div className="flex justify-end gap-2">
                          <button onClick={() => handleEdit(user)} className="p-2 text-slate-400 hover:bg-slate-100 hover:text-indigo-600 rounded-lg transition-colors"><Edit size={16} /></button>
                          <button onClick={() => handleDelete(user.id)} className="p-2 text-slate-400 hover:bg-rose-50 hover:text-rose-600 rounded-lg transition-colors"><Trash2 size={16} /></button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* TAB: SESSIONS */}
        {activeTab === 'sessions' && (
          <div>
            <div className="p-4 border-b border-slate-100 flex justify-between items-center bg-slate-50">
              <h2 className="font-black text-slate-700 flex items-center gap-2"><Activity size={18} className="text-indigo-500"/> Active Sessions (Last 24 Hrs)</h2>
              <button onClick={fetchData} className="text-slate-500 hover:text-slate-800 p-2 bg-white rounded-lg border border-slate-200 shadow-sm"><RefreshCw size={16} className={loading ? 'animate-spin' : ''}/></button>
            </div>
            
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="bg-slate-50 border-b border-slate-200">
                    <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider">User</th>
                    <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider">Login Time</th>
                    <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider">Last Activity</th>
                    <th className="p-4 text-xs font-black text-slate-500 uppercase tracking-wider text-right">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {loading ? (
                    <tr><td colSpan="4" className="p-8 text-center text-slate-400"><RefreshCw className="w-6 h-6 animate-spin mx-auto"/></td></tr>
                  ) : sessions.length === 0 ? (
                    <tr><td colSpan="4" className="p-8 text-center text-slate-500 font-medium">No active sessions found.</td></tr>
                  ) : sessions.map(session => (
                    <tr key={session.id} className="hover:bg-slate-50/50">
                      <td className="p-4">
                        <div className="font-bold text-slate-800">{session.user.username}</div>
                        <div className="text-xs text-slate-500 font-medium">{session.user.branch} • {session.user.role}</div>
                      </td>
                      <td className="p-4 text-sm font-medium text-slate-600">
                        {new Date(session.loginTime).toLocaleString('en-IN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: 'short' })}
                      </td>
                      <td className="p-4">
                         {/* If last active is within last 5 minutes, show as green "Online Now" */}
                         {new Date() - new Date(session.lastActive) < 5 * 60 * 1000 ? (
                            <span className="flex items-center gap-1.5 text-xs font-bold text-emerald-600 bg-emerald-50 px-2.5 py-1 rounded-full w-fit">
                              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span> Online Now
                            </span>
                         ) : (
                            <span className="text-sm font-medium text-slate-500">
                              {new Date(session.lastActive).toLocaleString('en-IN', { hour: '2-digit', minute: '2-digit' })}
                            </span>
                         )}
                      </td>
                      <td className="p-4 text-right">
                        <button 
                          onClick={() => handleForceLogout(session.id)}
                          className="px-3 py-1.5 bg-rose-50 hover:bg-rose-500 text-rose-600 hover:text-white rounded-lg text-xs font-bold transition-colors flex items-center gap-1.5 ml-auto"
                        >
                          <LogOut size={14} /> Force Logout
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>

      {/* CREATE / EDIT USER MODAL */}
      {showModal && (
        <div className="fixed inset-0 bg-stone-900/50 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl w-full max-w-md shadow-2xl overflow-hidden animate-in zoom-in-95 duration-200">
            <div className="px-6 py-4 border-b border-slate-100 flex justify-between items-center bg-slate-50">
              <h3 className="font-black text-slate-800 text-lg flex items-center gap-2">
                {editingId ? <Edit size={18} className="text-indigo-500"/> : <UserPlus size={18} className="text-indigo-500"/>} 
                {editingId ? 'Edit Employee' : 'Create Employee'}
              </h3>
              <button onClick={() => setShowModal(false)} className="text-slate-400 hover:text-slate-600 font-bold text-xl leading-none">&times;</button>
            </div>
            
            <form onSubmit={handleSubmit} className="p-6 space-y-4">
              <div>
                <label className="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1.5">Username (Employee Name)</label>
                <input 
                  required
                  type="text" 
                  value={formData.username}
                  onChange={e => setFormData({...formData, username: e.target.value})}
                  className="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:outline-none font-medium"
                  placeholder="e.g. Ravi Kumar"
                />
              </div>

              <div>
                <label className="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1.5">4-Digit PIN Code</label>
                <div className="relative">
                  <Key size={16} className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input 
                    required
                    type="password"
                    maxLength={4}
                    pattern="\d{4}"
                    title="Exactly 4 digits"
                    value={formData.pin}
                    onChange={e => setFormData({...formData, pin: e.target.value.replace(/\D/g, '')})}
                    className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-indigo-500 focus:outline-none font-mono font-bold tracking-widest text-lg"
                    placeholder="****"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1.5">Role Permission</label>
                  <select 
                    value={formData.role}
                    onChange={e => setFormData({...formData, role: e.target.value})}
                    className="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-indigo-500 font-bold text-slate-700"
                  >
                    <option value="worker">Worker</option>
                    <option value="admin">Administrator</option>
                  </select>
                </div>
                
                <div>
                  <label className="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1.5">Branch Assign</label>
                  <select 
                    value={formData.branch}
                    onChange={e => setFormData({...formData, branch: e.target.value})}
                    className="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-indigo-500 font-bold text-slate-700"
                  >
                    <option value="MAIN">Main Branch</option>
                    <option value="AP_BNG">AP BNG</option>
                    <option value="ALL">All Branches</option>
                  </select>
                </div>
              </div>

              {editingId && (
                <div>
                  <label className="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1.5">Account Status</label>
                  <select 
                    value={formData.status}
                    onChange={e => setFormData({...formData, status: e.target.value})}
                    className="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl focus:ring-2 focus:ring-indigo-500 font-bold text-slate-700"
                  >
                    <option value="Active">Active (Can Login)</option>
                    <option value="Suspended">Suspended (Locked Out)</option>
                  </select>
                </div>
              )}

              <div className="pt-4 flex gap-3">
                <button type="button" onClick={() => setShowModal(false)} className="flex-1 px-4 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl transition-colors">Cancel</button>
                <button type="submit" className="flex-1 px-4 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white font-bold rounded-xl shadow-sm transition-colors shadow-indigo-200">
                  {editingId ? 'Save Changes' : 'Create User'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
