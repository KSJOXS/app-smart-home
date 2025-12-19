import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
// import 'package:camera/camera.dart';
// import 'package:intl/intl.dart';
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
  bool _darkMode = false;
  String _selectedLanguage = 'Vietnamese';
  String _selectedTimeRange = 'Daily';
  List<String> timeRanges = ['Daily', 'Weekly', 'Monthly'];
  DateTime _selectedDate = DateTime.now();

  // Example data for statistics chart
  final Map<String, Map<String, int>> _statsData = {
    'Daily': {'Door': 13, 'Light': 10, 'Curtain': 8, 'Fan': 7},
    'Weekly': {'Door': 45, 'Light': 38, 'Curtain': 29, 'Fan': 32},
    'Monthly': {'Door': 180, 'Light': 155, 'Curtain': 120, 'Fan': 140},
  };

  // Face registration function with real camera
  Future<void> _registerFace() async {
    if (cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Camera not available')));
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FaceRegistrationCameraPage()),
      );
    }
  }

  // Navigate to statistics detail page
  void _navigateToStatisticsDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatisticsDetailPage(
          timeRange: _selectedTimeRange,
          selectedDate: _selectedDate,
        ),
      ),
    );
  }

  // Change date
  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  // Format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final currentStats = _statsData[_selectedTimeRange]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance.ref('users/${user?.uid}').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final userData = snapshot.data?.snapshot.value as Map?;
          final userName = userData?['name'] ?? 'User';
          final userEmail = userData?['email'] ?? user?.email ?? 'No email';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Text(
                      userName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(userName),
                  subtitle: Text(userEmail),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfilePage(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ---------------------------------------------------------------
              // NEW STATISTICS SECTION
              // ---------------------------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bar_chart, color: Colors.teal),
                          SizedBox(width: 8),
                          Text(
                            'Statistics',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.info_outline,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Time range selection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: timeRanges.map((range) {
                          return ChoiceChip(
                            label: Text(range),
                            selected: _selectedTimeRange == range,
                            selectedColor: Colors.teal,
                            labelStyle: TextStyle(
                              color: _selectedTimeRange == range
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            onSelected: (bool selected) {
                              setState(() {
                                _selectedTimeRange = range;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Date selection (only show when Daily is selected)
                      if (_selectedTimeRange == 'Daily')
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: () => _changeDate(-1),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _formatDate(_selectedDate),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: () => _changeDate(1),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),

                      // Simple statistics chart
                      Container(
                        height: 180,
                        margin: const EdgeInsets.only(top: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildBarChartItem(
                              'Door',
                              currentStats['Door']!,
                              Colors.blue,
                            ),
                            _buildBarChartItem(
                              'Light',
                              currentStats['Light']!,
                              Colors.orange,
                            ),
                            _buildBarChartItem(
                              'Curtain',
                              currentStats['Curtain']!,
                              Colors.green,
                            ),
                            _buildBarChartItem(
                              'Fan',
                              currentStats['Fan']!,
                              Colors.purple,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // View details button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToStatisticsDetail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.insights, size: 20),
                          label: const Text('View detailed statistics'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Card(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Security',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.face, color: Colors.purple),
                      title: const Text('Face registration'),
                      subtitle: const Text(
                        'Register face for smart access',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _registerFace,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'App Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Push notifications'),
                      subtitle: const Text('Receive push notifications'),
                      value: _notificationsEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Dark mode'),
                      subtitle: const Text('Enable dark theme'),
                      value: _darkMode,
                      onChanged: (bool value) {
                        setState(() {
                          _darkMode = value;
                        });
                      },
                    ),
                    ListTile(
                      title: const Text('Language'),
                      subtitle: Text(_selectedLanguage),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _showLanguageDialog();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: () {
                    _showLogoutDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Widget to create bar chart column
  Widget _buildBarChartItem(String label, int value, Color color) {
    final maxValue = _statsData[_selectedTimeRange]!.values.reduce(
          (a, b) => a > b ? a : b,
        );
    final heightRatio = value / maxValue;

    return Column(
      children: [
        Container(
          width: 40,
          height: 120 * heightRatio,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text(
              value.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Vietnamese'),
              leading: Radio<String>(
                value: 'Vietnamese',
                groupValue: _selectedLanguage,
                onChanged: (String? value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('English'),
              leading: Radio<String>(
                value: 'English',
                groupValue: _selectedLanguage,
                onChanged: (String? value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
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
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
