import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsDetailPage extends StatefulWidget {
  final String timeRange;
  final DateTime selectedDate;

  const StatisticsDetailPage({
    super.key,
    required this.timeRange,
    required this.selectedDate,
  });

  @override
  State<StatisticsDetailPage> createState() => _StatisticsDetailPageState();
}

class _StatisticsDetailPageState extends State<StatisticsDetailPage> {
  bool isWeekly = false;
  bool _isLoading = true;
  int totalActivities = 0;
  List<Map<String, dynamic>> historyLogs = [];
  Map<String, int> _deviceCounts = {};

  @override
  void initState() {
    super.initState();
    _fetchRealtimeData();
  }

  Future<void> _fetchRealtimeData() async {
    setState(() => _isLoading = true);
    final dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    final ref = FirebaseDatabase.instance.ref();

    try {
      // 1. ดึงสรุปยอดจาก daily_summary สำหรับวาดกราฟ
      final summarySnapshot = await ref.child('daily_summary/$dateKey').get();
      if (summarySnapshot.exists) {
        final data = summarySnapshot.value as Map;
        totalActivities = int.tryParse(data['total_usage'].toString()) ?? 0;

        if (data['devices'] != null) {
          _deviceCounts = (data['devices'] as Map).map((k, v) =>
              MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0));
        }
      }

      // 2. ดึงประวัติละเอียดจาก usage_logs ตามวันที่เลือก
      final logsSnapshot = await ref.child('usage_logs/$dateKey').get();
      historyLogs.clear();

      if (logsSnapshot.exists) {
        final Map<dynamic, dynamic> logsData = logsSnapshot.value as Map;

        logsData.forEach((key, value) {
          final logItem = value as Map;
          historyLogs.add({
            'device': logItem['device'] ?? 'Unknown',
            'time': logItem['time'] ?? '--:--', // ดึงเวลา "15:08:30"
            'status': logItem['status'], // ดึงค่า true/false
            'userEmail': logItem['userEmail'] ?? 'Unknown',
            'rawKey': key, // ใช้ Milliseconds key ในการเรียงลำดับ
          });
        });

        // เรียงลำดับประวัติล่าสุดอยู่บนสุด
        historyLogs.sort((a, b) => b['rawKey'].compareTo(a['rawKey']));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }

    setState(() => _isLoading = false);
  }

  Color _getDeviceColor(String deviceName) {
    switch (deviceName.toLowerCase()) {
      case 'led1':
        return Colors.orange[400]!;
      case 'led2':
        return Colors.amber[600]!;
      case 'motor':
        return Colors.purple[400]!;
      case 'servo_angle':
        return Colors.blue[400]!;
      default:
        return Colors.teal[400]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("History Statistics",
            style: TextStyle(
                color: Colors.orange[300], fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : RefreshIndicator(
              onRefresh: _fetchRealtimeData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildDateDisplay(),
                    const SizedBox(height: 20),
                    _buildChartCard(),
                    const SizedBox(height: 20),
                    _buildOverviewCards(),
                    const SizedBox(height: 20),
                    _buildRecentActivities(), // ส่วนแสดงประวัติจริง
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateDisplay() {
    return Text(DateFormat('dd MMMM yyyy').format(widget.selectedDate),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18));
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Device Usage Count",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: const FlTitlesData(
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor:
                        Colors.teal.withOpacity(0.9), // แก้ Error image_ae2e45
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: _deviceCounts.entries.map((e) {
                  return LineChartBarData(
                    spots: [const FlSpot(0, 0), FlSpot(1, e.value.toDouble())],
                    color: _getDeviceColor(e.key),
                    barWidth: 4,
                    dotData: const FlDotData(show: true),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 15),
          _buildChartLegend(),
        ],
      ),
    );
  }

  Widget _buildChartLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: _deviceCounts.entries.map((entry) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _getDeviceColor(entry.key))),
            const SizedBox(width: 4),
            Text("${entry.key.toUpperCase()} (${entry.value})",
                style: const TextStyle(fontSize: 11)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildOverviewCards() {
    return Row(
      children: [
        Expanded(child: _overviewItem("$totalActivities", "Total Usage")),
        const SizedBox(width: 16),
        Expanded(child: _overviewItem("${historyLogs.length}", "Total Logs")),
      ],
    );
  }

  Widget _overviewItem(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Recent Activities",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(height: 25),
          if (historyLogs.isEmpty)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("No records found for this date.")))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: historyLogs.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 25, color: Color(0xFFF5F5F5)),
              itemBuilder: (context, index) {
                final log = historyLogs[index];
                final bool isOn = log['status'] == true;

                return Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          _getDeviceColor(log['device']).withOpacity(0.1),
                      child: Icon(Icons.power_settings_new,
                          color: _getDeviceColor(log['device']), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log['device'].toString().toUpperCase(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(log['userEmail'],
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          log['time'], // แสดงค่า "15:08:30"
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        Text(
                          isOn ? "TURNED ON" : "TURNED OFF",
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isOn ? Colors.green : Colors.red),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
