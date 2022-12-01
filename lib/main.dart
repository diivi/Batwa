import 'dart:convert';

import 'package:batwa/db/transactions_database.dart';
import 'package:batwa/utils/user_preferences.dart';
import 'package:decimal/decimal.dart';
import 'package:decimal/intl.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter/material.dart';
import './model/transaction.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserPreferences.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Transaction> transactions = [];
  Decimal cashFlow = Decimal.zero;
  String quote = '';
  String author = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    refreshTransactions();
    fetchRandomQuote();
  }

  void fetchRandomQuote() {
    var response = http.get(Uri.parse(
        'https://api.quotable.io/random?tags=inspirational&maxLength=180'));
    response.then((value) {
      var quoteJson = jsonDecode(value.body);
      setState(() {
        quote = quoteJson['content'];
        author = quoteJson['author'];
      });
    });
  }

  Future refreshTransactions() async {
    setState(() {
      isLoading = true;
    });
    transactions = await TransactionsDatabase.instance.readAllTransactions();
    cashFlow = await TransactionsDatabase.instance.getMonthlyCashFlow();
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: // static container with greeting followed by scrollable list of transactions
          Column(
        children: [
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xff2a2a72),
                  Color(0xff000000),
                ],
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Hello, Divi!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 15),
                        width: 250,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quote,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            Text(
                              "- $author",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: Text(
                    NumberFormat.simpleCurrency(
                      locale: 'en_IN',
                    ).format(DecimalIntl(cashFlow)),
                    style: TextStyle(
                      color:
                          cashFlow < Decimal.zero ? Colors.red : Colors.green,
                      fontSize: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                // text and button
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                width: MediaQuery.of(context).size.width,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Showing ${transactions.length} Txns',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    ElevatedButton(
                      onPressed: () async {
                        bool smsPermission = await getSmsPermission();
                        if (smsPermission) {
                          setState(() {
                            isLoading = true;
                          });
                          List<Transaction> transactions = await getAllSms();
                          setState(() {
                            isLoading = false;
                            this.transactions = transactions;
                          });
                        } else {
                          await AppSettings.openAppSettings();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Please grant SMS permission to continue'),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2a2a72),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Fetch Transactions",
                          style: TextStyle(fontWeight: FontWeight.w300)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: Text('Loading...'),
                  )
                : transactions.isEmpty
                    ? const Center(
                        child: Text("No transactions found"),
                      )
                    : ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          return Card(
                            child: ListTile(
                              leading: transactions[index].transferType ==
                                      TransactionType.income
                                  ? const Icon(
                                      Icons.arrow_upward,
                                      color: Colors.green,
                                    )
                                  : const Icon(
                                      Icons.arrow_downward,
                                      color: Colors.red,
                                    ),
                              title: Text(transactions[index].amount),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

Future<List<Transaction>> getAllSms() async {
  SmsQuery query = SmsQuery();
  List<SmsMessage> messages = await query.querySms(address: 'JM-BOBTXN');
  List<Transaction> transactions = [];
  for (var message in messages) {
    String? amountWithCurrency = message.body?.split(' ')[0];
    String? amount =
        amountWithCurrency?.substring(3, amountWithCurrency.length);
    TransactionType transferType = message.body?.contains('Credited') ?? false
        ? TransactionType.income
        : TransactionType.expense;
    //01-12-2022 20:32:25
    DateTime dateTime = DateFormat("dd-MM-yyyy HH:mm:ss")
        .parse(message.body!.split("(")[1].split(")")[0]);
    Transaction transaction = Transaction(
      transferType: transferType,
      amount: amount!,
      dateTime: dateTime,
    );
    transactions.add(transaction);
  }
  // shared preference se date check kar if it exists, if it doesnt then add all transactions and set shared preference to current date
  if (UserPreferences.getLastSyncDate() == null) {
    await TransactionsDatabase.instance.insertMany(transactions);
    await UserPreferences.setLastSyncDate(DateTime.now().toString());
  } else {
    DateTime lastSyncDate = DateTime.parse(UserPreferences.getLastSyncDate()!);
    List<Transaction> newTransactions = [];
    for (var transaction in transactions) {
      if (transaction.dateTime!.isAfter(lastSyncDate)) {
        newTransactions.add(transaction);
      }
    }
    if (newTransactions.isNotEmpty) {
      await TransactionsDatabase.instance.insertMany(newTransactions);
      await UserPreferences.setLastSyncDate(DateTime.now().toString());
    }
  }
  return transactions;
}

Future<bool> getSmsPermission() async {
  PermissionStatus permission = await Permission.sms.status;
  if (permission.isGranted) {
    return true;
  } else {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.sms,
    ].request();
    return statuses[Permission.sms]!.isGranted;
  }
}
