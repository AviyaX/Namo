enum AutoDownload {
  wifiOnly('Wi-Fi only'),
  any('Any connection'),
  off('Off');

  const AutoDownload(this.label);

  final String label;
}
