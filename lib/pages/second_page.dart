import 'package:flutter/material.dart';

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 246, 246, 247),
      appBar: AppBar(
        title: const Text('Admin Portal'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Welcome to Admin Portal",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: const <Widget>[
                  ListTile(
                    leading: Icon(Icons.list_alt),
                    title: Text("List of All Orders"),
                  ),
                  ListTile(
                    leading: Icon(Icons.business),
                    title: Text("Company Details"),
                  ),
                  ListTile(
                    leading: Icon(Icons.people),
                    title: Text("Manage Users"),
                  ),
                  ListTile(
                    leading: Icon(Icons.inventory),
                    title: Text("Inventory Management"),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
