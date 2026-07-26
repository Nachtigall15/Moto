import { useRef } from 'react';
import { exportBackup, importBackup, type BackupData } from '../db';

interface Props {
  onImported: () => void;
}

export function BackupControls({ onImported }: Props) {
  const fileInputRef = useRef<HTMLInputElement>(null);

  async function handleExport() {
    const backup = await exportBackup();
    const blob = new Blob([JSON.stringify(backup, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `dauerkarte-fc-backup-${new Date().toISOString().slice(0, 10)}.json`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }

  function handleImportClick() {
    fileInputRef.current?.click();
  }

  async function handleFileSelected(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;

    const confirmed = window.confirm(
      'Import überschreibt alle vorhandenen Daten in dieser App. Fortfahren?',
    );
    if (!confirmed) return;

    try {
      const text = await file.text();
      const data = JSON.parse(text) as BackupData;
      await importBackup(data);
      onImported();
      window.alert('Backup erfolgreich importiert.');
    } catch (err) {
      window.alert(`Import fehlgeschlagen: ${err instanceof Error ? err.message : 'Unbekannter Fehler'}`);
    }
  }

  return (
    <div className="backup-controls">
      <button type="button" className="btn btn--ghost" onClick={handleExport}>
        Backup exportieren
      </button>
      <button type="button" className="btn btn--ghost" onClick={handleImportClick}>
        Backup importieren
      </button>
      <input
        ref={fileInputRef}
        type="file"
        accept="application/json"
        style={{ display: 'none' }}
        onChange={handleFileSelected}
      />
    </div>
  );
}
