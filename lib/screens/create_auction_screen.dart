import 'package:flutter/material.dart';
import '../models/auction.dart';
import '../services/api_service.dart';

class CreateAuctionScreen extends StatefulWidget {
  const CreateAuctionScreen({super.key});

  @override
  State<CreateAuctionScreen> createState() => _CreateAuctionScreenState();
}

class _CreateAuctionScreenState extends State<CreateAuctionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _reserveController = TextEditingController();
  final _durationController = TextEditingController();

  Future<void> _createAuction() async {
    if (_formKey.currentState!.validate()) {
      final auction = Auction(
        id: 'au_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text,
        reservePrice: double.parse(_reserveController.text),
        currentPrice: double.parse(_reserveController.text),
        endTime: DateTime.now().add(
          Duration(hours: int.parse(_durationController.text)),
        ),
        state: 'PENDING',
      );

      final response = await ApiService.createAuction(auction);
      if (!mounted) {
        return;
      }
      if (response['success']) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auction created successfully!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Auction')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Auction Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) => value!.isEmpty ? 'Title required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reserveController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reserve Price',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Reserve price required';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Valid price required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (hours)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Duration required';
                  }
                  final hours = int.tryParse(value);
                  if (hours == null || hours <= 0) {
                    return 'Valid hours required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _createAuction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Create Auction',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _reserveController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}
