import { useState, useEffect } from 'react';

export function usePermissions() {
  const [permissions, setPermissions] = useState({
    canCreate: false,
    canEdit: false,
    canDelete: false,
    canViewReports: false,
    isAdmin: false
  });

  useEffect(() => {
    try {
      const role = localStorage.getItem('erp_role');
      const permsStr = localStorage.getItem('erp_permissions');
      const perms = permsStr ? JSON.parse(permsStr) : { create: true, edit: true, delete: false, reports: false };
      
      setPermissions({
        isAdmin: role === 'admin',
        canCreate: role === 'admin' || perms.create,
        canEdit: role === 'admin' || perms.edit,
        canDelete: role === 'admin' || perms.delete,
        canViewReports: role === 'admin' || perms.reports
      });
    } catch (e) {
      // Default fallback
      setPermissions({
        canCreate: true, canEdit: true, canDelete: false, canViewReports: false, isAdmin: false
      });
    }
  }, []);

  return permissions;
}
