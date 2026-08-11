import 'package:flutter/material.dart';

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 246, 246, 247),
      appBar: AppBar(
        title: const Text('Second Page'),
      ),
      body: Center(
        child:Column(
          mainAxisAlignment:MainAxisAlignment.center,
          children:[
            const Text("Welcome to Admin Portal",style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Go Back'),
        ),
        Table()
        ],
        ),

      ),
    );
  }
}
