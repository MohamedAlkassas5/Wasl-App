import 'wasl_failure.dart';

/// حالة أي عملية بتجيب بيانات: بتحمّل، نجحت، أو فشلت.
///
/// الشاشات قبل كده كانت بتمثّل الحالات دي بمتغيرين منفصلين (`_isLoading` و
/// `_error`) وكل شاشة بطريقتها، فكان ممكن تلاقي الاتنين `true` مع بعض أو
/// تلاقي شاشة بتعرض «مفيش نتايج» وهي أصلاً لسه بتحمّل. النوع ده بيخلي الحالات
/// دي **متبادلة** — مستحيل تكون في اتنين منهم في نفس الوقت.
sealed class WaslAsync<T> {
  const WaslAsync();

  /// لسه بيحمّل ومفيش بيانات.
  const factory WaslAsync.loading() = WaslAsyncLoading<T>;

  /// خلص بنجاح.
  const factory WaslAsync.data(T value) = WaslAsyncData<T>;

  /// فشل.
  const factory WaslAsync.failure(WaslFailure failure) = WaslAsyncFailure<T>;

  bool get isLoading => this is WaslAsyncLoading<T>;

  /// البيانات لو موجودة، وإلا null.
  T? get valueOrNull => this is WaslAsyncData<T> ? (this as WaslAsyncData<T>).value : null;

  /// الفشل لو موجود، وإلا null.
  WaslFailure? get failureOrNull =>
      this is WaslAsyncFailure<T> ? (this as WaslAsyncFailure<T>).failure : null;
}

class WaslAsyncLoading<T> extends WaslAsync<T> {
  const WaslAsyncLoading();
}

class WaslAsyncData<T> extends WaslAsync<T> {
  const WaslAsyncData(this.value);
  final T value;
}

class WaslAsyncFailure<T> extends WaslAsync<T> {
  const WaslAsyncFailure(this.failure);
  final WaslFailure failure;
}

/// يشغّل عملية ويحوّل أي استثناء لحالة فشل معروضة.
///
/// معناها إن الشاشة مابتشوفش استثناءات خام أبداً — دي النقطة اللي بيتحوّل
/// عندها `SocketException` لجملة عربية، مرة واحدة في مكان واحد بدل ما تتكرر
/// في كل شاشة.
Future<WaslAsync<T>> runAsync<T>(Future<T> Function() work) async {
  try {
    return WaslAsync.data(await work());
  } catch (error) {
    return WaslAsync.failure(WaslFailure.from(error));
  }
}
