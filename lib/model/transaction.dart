final String tableTransactions = 'transactions';

class TransactionFields {
  static final List<String> values = [
    /// Add all fields
    id, transferType, amount, sender, receiver, dateTime, description, category
  ];

  static final String id = '_id';
  static final String transferType = 'transferType';
  static final String amount = 'amount';
  static final String sender = 'sender';
  static final String receiver = 'receiver';
  static final String dateTime = 'dateTime';
  static final String description = 'description';
  static final String category = 'category';
}

enum TransactionType { income, expense, transfer, investment }

class Transaction {
  final int? id;
  TransactionType transferType = TransactionType.income;
  String amount = "";
  String? sender;
  String? receiver;
  DateTime? dateTime;
  String? description;
  String? category;
  Transaction({
    required this.transferType,
    required this.amount,
    required this.dateTime,
    this.sender,
    this.receiver,
    this.description,
    this.category,
    this.id,
  });

  Map<String, Object?> toJson() => {
        TransactionFields.transferType: transferType.toString(),
        TransactionFields.amount: amount,
        TransactionFields.sender: sender,
        TransactionFields.receiver: receiver,
        TransactionFields.dateTime: dateTime.toString(),
        TransactionFields.description: description,
        TransactionFields.category: category,
      };

  static Transaction fromJson(Map<String, Object?> json) => Transaction(
        transferType: TransactionType.values.firstWhere((e) =>
            e.toString() == json[TransactionFields.transferType] as String),
        amount: json[TransactionFields.amount] as String,
        sender: json[TransactionFields.sender] as String?,
        receiver: json[TransactionFields.receiver] as String?,
        dateTime: DateTime.parse(json[TransactionFields.dateTime] as String),
        description: json[TransactionFields.description] as String?,
        category: json[TransactionFields.category] as String?,
      );

  Transaction copy({
    int? id,
    TransactionType? transferType,
    String? amount,
    String? sender,
    String? receiver,
    DateTime? dateTime,
    String? description,
    String? category,
  }) =>
      Transaction(
        id: id ?? this.id,
        transferType: transferType ?? this.transferType,
        amount: amount ?? this.amount,
        sender: sender ?? this.sender,
        receiver: receiver ?? this.receiver,
        dateTime: dateTime ?? this.dateTime,
        description: description ?? this.description,
        category: category ?? this.category,
      );
}
