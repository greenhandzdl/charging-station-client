import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/charging_provider.dart';
import '../../services/api_service.dart';
import 'repair_screen.dart';

/// Result of scanning a QR code.
class _ScanResult {
  final String chargerId;
  final String? stationName;
  final String? chargerCode;
  final String? type;
  final String? sessionId;

  _ScanResult({
    required this.chargerId,
    this.stationName,
    this.chargerCode,
    this.type,
    this.sessionId,
  });
}

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  MobileScannerController? _scannerController;
  bool _isProcessing = false;
  bool _cameraError = false;
  bool _useManualInput = false;

  // Manual fallback
  final _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _useManualInput = kIsWeb; // Web has no camera support
    if (!kIsWeb) {
      _scannerController = MobileScannerController();
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫码充电'),
        actions: kIsWeb
            ? null
            : [
                IconButton(
                  icon: Icon(_useManualInput ? Icons.qr_code : Icons.edit),
                  tooltip: _useManualInput ? '扫码模式' : '手动输入',
                  onPressed: () => setState(() => _useManualInput = !_useManualInput),
                ),
              ],
      ),
      body: _useManualInput ? _buildManualInput() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    if (_cameraError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('无法访问摄像头',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              const Text('请检查摄像头权限，或切换至手动输入模式'),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.edit),
                label: const Text('切换至手动输入'),
                onPressed: () =>
                    setState(() => _useManualInput = true),
              ),
            ],
          ),
        ),
      );
    }

    final scanner = _scannerController;
    if (scanner == null) {
      // Web platform — no camera support, show manual input prompt
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('Web端不支持摄像头扫码',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              const Text('请使用手动输入模式'),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.edit),
                label: const Text('切换至手动输入'),
                onPressed: () => setState(() => _useManualInput = true),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: scanner,
          onDetect: _onDetect,
          errorBuilder: (context, error) {
            // Camera not available — show fallback
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _cameraError = true);
            });
            return const SizedBox.shrink();
          },
        ),
        // Scan overlay guide
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                '将二维码对准框内',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildManualInput() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 32),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '手动输入充电桩ID或编码，\n或切换回扫码模式快速扫描',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _manualController,
            decoration: const InputDecoration(
              labelText: '充电桩ID / 编码',
              hintText: '输入充电桩ID或编码',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code_scanner),
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isProcessing
                ? null
                : () {
                    final code = _manualController.text.trim();
                    if (code.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入充电桩ID或编码')),
                      );
                      return;
                    }
                    _handleScanResult(code);
                  },
            icon: const Icon(Icons.search),
            label: Text(_isProcessing ? '查询中...' : '查询充电桩'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _isProcessing = true);

    // Haptic feedback
    HapticFeedback.heavyImpact();

    await _handleScanResult(barcode.rawValue!);
  }

  Future<void> _handleScanResult(String rawValue) async {
    try {
      _ScanResult scanResult;

      // Try to parse as JSON first
      try {
        final json = jsonDecode(rawValue) as Map<String, dynamic>;
        scanResult = _ScanResult(
          chargerId: json['chargerId'] as String? ?? '',
          stationName: json['stationName'] as String?,
          chargerCode: json['chargerCode'] as String?,
          type: json['type'] as String?,
          sessionId: json['sessionId'] as String?,
        );
        if (scanResult.chargerId.isEmpty) {
          throw const FormatException('缺少 chargerId');
        }
      } catch (_) {
        // Not JSON — treat as raw code and look up
        try {
          final data = await ApiService.getChargerByCode(rawValue);
          final charger = ChargerModel.fromJson(data);
          scanResult = _ScanResult(
            chargerId: charger.id,
            stationName: charger.stationName,
            chargerCode: charger.chargerCode,
            type: charger.type,
          );
        } catch (_) {
          // Try as charger ID directly
          scanResult = _ScanResult(chargerId: rawValue);
        }
      }

      await _showActionSheet(scanResult);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showActionSheet(_ScanResult result) async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with charger info
              Row(
                children: [
                  const Icon(Icons.ev_station, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '充电桩 ${result.chargerCode ?? result.chargerId}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (result.stationName != null)
                          Text(
                            result.stationName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (result.type != null)
                          Text(
                            '类型: ${result.type}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action buttons
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startCharging(result.chargerId, sessionId: result.sessionId);
                },
                icon: const Icon(Icons.flash_on),
                label: const Text('启动充电'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 8),

              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToRepair(result);
                },
                icon: const Icon(Icons.build),
                label: const Text('报修'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 8),

              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showChargerInfo(result);
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('查看信息'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 8),

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Resume scanning — do nothing extra
                },
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startCharging(String chargerId, {String? sessionId}) async {
    if (!mounted) return;
    try {
      // First, select/bind the charger (if sessionId is available)
      if (sessionId != null && sessionId.isNotEmpty) {
        await ApiService.selectCharger(chargerId, sessionId);
      }

      // Then start charging
      await context.read<ChargingProvider>().startCharge(chargerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('充电已启动'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('启动充电失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToRepair(_ScanResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RepairScreen(
          initialChargerId: result.chargerId,
          initialChargerCode: result.chargerCode,
        ),
      ),
    );
  }

  Future<void> _showChargerInfo(_ScanResult result) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('充电桩信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('ID', result.chargerId),
            _infoRow('编码', result.chargerCode ?? '-'),
            _infoRow('所属站点', result.stationName ?? '-'),
            _infoRow('类型', result.type ?? '-'),
            _infoRow('会话ID', result.sessionId ?? '-'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
