import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_alert_screen.dart';
import 'api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _alerts = [];
  bool _isLoading = true;
  String? _chatId;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _chatId = prefs.getString('chat_id');

      if (_chatId != null) {
        final alerts = await ApiService.getAlerts(_chatId!);
        setState(() {
          _alerts = alerts;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading alerts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAlert(int alertId) async {
    if (_chatId == null) return;

    try {
      await ApiService.deleteAlert(chatId: _chatId!, alertId: alertId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadAlerts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Alert',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: _loadAlerts,
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Colors.deepPurple,
                ),
              )
            : _alerts.isEmpty
                ? Center(
                    child: Text(
                      'No alerts yet',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAlerts,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _alerts.length,
                      itemBuilder: (context, index) {
                        final alert = _alerts[index];
                        final isAbove = alert['alert_type'] == 'above';
                        
                        return Card(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.deepPurple.withOpacity(0.3),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple,
                              child: Icon(
                                isAbove ? Icons.arrow_upward : Icons.arrow_downward,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              alert['symbol'],
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Target: ${alert['target_price']}',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  alert['created_at'],
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteAlert(alert['id']),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddAlertScreen()),
            );
            if (result == true) {
              _loadAlerts();
            }
          },
          backgroundColor: Colors.deepPurple,
          child: const Icon(
            Icons.add,
            color: Colors.white,
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
