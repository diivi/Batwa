import 'package:batwa/model/transaction.dart' as transactionModel;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:decimal/decimal.dart';

class TransactionsDatabase {
  static final TransactionsDatabase instance = TransactionsDatabase._init();

  static Database? _database;

  TransactionsDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('transactions.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute(
      '''
      CREATE TABLE ${transactionModel.tableTransactions} (
        ${transactionModel.TransactionFields.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${transactionModel.TransactionFields.transferType} TEXT NOT NULL,
        ${transactionModel.TransactionFields.amount} TEXT NOT NULL,
        ${transactionModel.TransactionFields.dateTime} TEXT NOT NULL,
        ${transactionModel.TransactionFields.sender} TEXT,
        ${transactionModel.TransactionFields.receiver} TEXT,
        ${transactionModel.TransactionFields.description} TEXT,
        ${transactionModel.TransactionFields.category} TEXT
      )
      ''',
    );
  }

  Future<transactionModel.Transaction> create(
      transactionModel.Transaction transaction) async {
    final db = await instance.database;
    final id = await db.insert(
        transactionModel.tableTransactions, transaction.toJson());
    return transaction.copy(id: id);
  }

  Future<transactionModel.Transaction> insertMany(
      List<transactionModel.Transaction> transactions) async {
    final db = await instance.database;
    for (var transaction in transactions) {
      await db.insert(transactionModel.tableTransactions, transaction.toJson());
    }
    return transactions.first;
  }

  Future<transactionModel.Transaction> readTransaction(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      transactionModel.tableTransactions,
      columns: transactionModel.TransactionFields.values,
      where: '${transactionModel.TransactionFields.id} = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return transactionModel.Transaction.fromJson(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<transactionModel.Transaction>> readAllTransactions() async {
    final db = await instance.database;
    final orderBy = '${transactionModel.TransactionFields.dateTime} DESC';
    final result =
        await db.query(transactionModel.tableTransactions, orderBy: orderBy);
    return result
        .map((json) => transactionModel.Transaction.fromJson(json))
        .toList();
  }

  Future<int> update(transactionModel.Transaction transaction) async {
    final db = await instance.database;
    return db.update(
      transactionModel.tableTransactions,
      transaction.toJson(),
      where: '${transactionModel.TransactionFields.id} = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      transactionModel.tableTransactions,
      where: '${transactionModel.TransactionFields.id} = ?',
      whereArgs: [id],
    );
  }

  Future<Decimal> getMonthlyCashFlow() async {
    final db = await instance.database;
    var incomeSet = await db.rawQuery(
        'SELECT SUM(amount) FROM transactions WHERE transferType = "TransactionType.income" AND dateTime BETWEEN date("now", "start of month") AND date("now", "start of month", "+1 month", "-1 day")');
    var expenseSet = await db.rawQuery(
        'SELECT SUM(amount) FROM transactions WHERE transferType = "TransactionType.expense" AND dateTime BETWEEN date("now", "start of month") AND date("now", "start of month", "+1 month", "-1 day")');

    var income = incomeSet.first.values.first;
    var expense = expenseSet.first.values.first;
    return Decimal.parse(income.toString()) - Decimal.parse(expense.toString());
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
