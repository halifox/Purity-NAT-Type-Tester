import 'dart:async';

final EventBus bus = EventBus();

class EventBus {
  static final EventBus _instance = EventBus._internal();

  factory EventBus() => _instance;

  EventBus._internal();

  final StreamController _controller = StreamController.broadcast();

  Stream get stream => _controller.stream;

  void emit(event) => _controller.add(event);
}
