import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart';
import 'statistics_detail_page.dart';
import 'face_registration_page.dart';
import 'profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'Vietnamese';
  DateTime _selectedDate = DateTime.now();

  // ตัวช่วยจัดการสีของอุปกรณ์ต่างๆ ให้เป็นมาตรฐานเดียวกัน
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

  // ฟังก์ชันเปลี่ยนวันที่โดยใช้ Duration
  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(user),
          const SizedBox(height: 20),
          _buildChartSection(dateKey),
          const SizedBox(height: 16),
          _buildAppSettingsSection(),
          const SizedBox(height: 24),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  // ส่วนแสดงกราฟสถิติ
  Widget _buildChartSection(String dateKey) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, color: Colors.teal),
              SizedBox(width: 8),
              Text("Device Usage Overview",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 16),
          // ส่วนเลือกวันที่
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeDate(-1)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8)),
                child: Text(DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeDate(1)),
            ],
          ),
          const SizedBox(height: 10),
          // ส่วนแสดงผล LineChart
          SizedBox(
            height: 220,
            child: StreamBuilder(
              stream: FirebaseDatabase.instance
                  .ref('daily_summary/$dateKey')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data?.snapshot.value == null) {
                  return const Center(
                      child: Text("No records for this date",
                          style: TextStyle(color: Colors.grey)));
                }

                final data = snapshot.data!.snapshot.value as Map;
                final Map<String, int> deviceCounts =
                    (data['devices'] as Map? ?? {}).map((k, v) => MapEntry(
                        k.toString(), int.tryParse(v.toString()) ?? 0));

                return LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        // แก้ไข: ใช้ tooltipBgColor แทน getTooltipColor สำหรับ fl_chart v0.64.0
                        tooltipBgColor: Colors.teal.withOpacity(0.9),
                        getTooltipItems: (List<LineBarSpot> touchedSpots) {
                          return touchedSpots.map((spot) {
                            final deviceName = deviceCounts.keys
                                .elementAt(spot.barIndex)
                                .toUpperCase();
                            return LineTooltipItem(
                              '$deviceName\n${spot.y.toInt()} times',
                              const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    gridData:
                        const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: const FlTitlesData(
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: deviceCounts.entries.map((e) {
                      return LineChartBarData(
                        spots: [
                          const FlSpot(0, 0),
                          FlSpot(1, e.value.toDouble())
                        ],
                        color: _getDeviceColor(e.key),
                        barWidth: 5,
                        isCurved: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                            show: true,
                            color: _getDeviceColor(e.key).withOpacity(0.1)),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // คำอธิบายสีของอุปกรณ์ (Legend)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegend("LED1", Colors.orange[400]!),
              _buildLegend("LED2", Colors.amber[600]!),
              _buildLegend("Motor", Colors.purple[400]!),
              _buildLegend("Servo", Colors.blue[400]!),
            ],
          ),
          const SizedBox(height: 16),
          // ปุ่มดูรายละเอียดสถิติทั้งหมด
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => StatisticsDetailPage(
                          timeRange: 'Daily', selectedDate: _selectedDate))),
              icon: const Icon(Icons.analytics),
              label: const Text("View Full History"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String name, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ส่วนแสดงข้อมูลโปรไฟล์ผู้ใช้
  Widget _buildProfileCard(User? user) {
    return StreamBuilder(
      stream: FirebaseDatabase.instance.ref('users/${user?.uid}').onValue,
      builder: (context, snapshot) {
        final userData = snapshot.data?.snapshot.value as Map?;
        final name = userData?['name'] ?? 'User';
        return Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: ListTile(
            leading: CircleAvatar(
                backgroundColor: Colors.teal,
                child: Text(name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white))),
            title:
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(user?.email ?? 'No email'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const ProfilePage())),
          ),
        );
      },
    );
  }

  // ส่วนการตั้งค่าแอปพลิเคชัน
  Widget _buildAppSettingsSection() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Notifications'),
            secondary:
                const Icon(Icons.notifications_active, color: Colors.orange),
            value: _notificationsEnabled,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
          ),
          ListTile(
            leading: const Icon(Icons.face, color: Colors.purple),
            title: const Text('Face Registration'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              if (cameras.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Camera not available')));
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => FaceRegistrationCameraPage()));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.blue),
            title: const Text('Language'),
            subtitle: Text(_selectedLanguage),
            onTap: _showLanguageDialog,
          ),
        ],
      ),
    );
  }

  // ปุ่มออกจากระบบ
  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      onPressed: _showLogoutDialog,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.logout),
      label:
          const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                title: const Text('Vietnamese'),
                onTap: () {
                  setState(() => _selectedLanguage = 'Vietnamese');
                  Navigator.pop(context);
                }),
            ListTile(
                title: const Text('English'),
                onTap: () {
                  setState(() => _selectedLanguage = 'English');
                  Navigator.pop(context);
                }),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
                Navigator.pop(context);
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
