// نماذج محادثة الطلب. مشتركة بين شاشة العميل وشاشة الكابتن — محادثة واحدة
// لكل طلب، مهما كان نوعه (مطاعم / صيدلية / متاجر / وصللي).

/// نوع الرسالة. الأسماء دي زي ما السيرفر بيبعتها بالظبط.
enum WaslMessageKind { text, image, priceProposal, priceDecision, system }

WaslMessageKind _kindFrom(String? raw) {
  switch (raw) {
    case 'image':
      return WaslMessageKind.image;
    case 'price_proposal':
      return WaslMessageKind.priceProposal;
    case 'price_decision':
      return WaslMessageKind.priceDecision;
    case 'system':
      return WaslMessageKind.system;
    default:
      return WaslMessageKind.text;
  }
}

class WaslChatMessage {
  const WaslChatMessage({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.senderRole,
    required this.kind,
    this.body,
    this.attachmentUrl,
    this.proposalId,
    this.createdAt,
  });

  final int id;
  final int orderId;
  final int senderId;
  final String senderRole; // customer | driver | system
  final WaslMessageKind kind;
  final String? body;
  final String? attachmentUrl;
  final int? proposalId;
  final DateTime? createdAt;

  factory WaslChatMessage.fromJson(Map<String, dynamic> json) {
    return WaslChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderId: (json['orderId'] as num?)?.toInt() ?? 0,
      senderId: (json['senderId'] as num?)?.toInt() ?? 0,
      senderRole: json['senderRole']?.toString() ?? 'system',
      kind: _kindFrom(json['kind']?.toString()),
      body: json['body']?.toString(),
      attachmentUrl: json['attachmentUrl']?.toString(),
      proposalId: (json['proposalId'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  /// هل الرسالة دي مني؟ بيتحدد بالـ id مش بالدور، عشان نفس الشاشة بتشتغل
  /// للطرفين.
  bool isMine(int myUserId) => senderId == myUserId;
}

enum WaslProposalStatus { pending, approved, rejected }

WaslProposalStatus _statusFrom(String? raw) {
  switch (raw) {
    case 'approved':
      return WaslProposalStatus.approved;
    case 'rejected':
      return WaslProposalStatus.rejected;
    default:
      return WaslProposalStatus.pending;
  }
}

/// طلب تعديل سعر المشتريات. الموافقة عليه هي الطريقة **الوحيدة** اللي بيتغيّر
/// بيها سعر مشتريات الطلب بعد إنشائه.
class WaslPriceProposal {
  const WaslPriceProposal({
    required this.id,
    required this.orderId,
    required this.oldItemsPrice,
    required this.newItemsPrice,
    required this.status,
    this.reason,
  });

  final int id;
  final int orderId;
  final double oldItemsPrice;
  final double newItemsPrice;
  final WaslProposalStatus status;
  final String? reason;

  bool get isPending => status == WaslProposalStatus.pending;

  factory WaslPriceProposal.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) =>
        double.tryParse(value?.toString() ?? '') ?? 0;

    return WaslPriceProposal(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderId: (json['orderId'] as num?)?.toInt() ?? 0,
      oldItemsPrice: toDouble(json['oldItemsPrice']),
      newItemsPrice: toDouble(json['newItemsPrice']),
      status: _statusFrom(json['status']?.toString()),
      reason: json['reason']?.toString(),
    );
  }
}
