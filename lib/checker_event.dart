import 'event_bus.dart';

enum EventState { idle, running, success, timeout, error, never }

CheckerEvent checkerEvent = CheckerEvent();

void updateCheckerEvent() {
  bus.emit(checkerEvent);
}

class CheckerEvent {
  EventState initializeLocalAddresses = EventState.idle;
  EventState performPhase1MappingTest = EventState.idle;
  EventState performPhase2MappingTest = EventState.idle;
  EventState performPhase3MappingTest = EventState.idle;
  EventState performPhase1FilteringTest = EventState.idle;
  EventState performPhase2FilteringTest = EventState.idle;
  EventState result = EventState.idle;

  clear() {
    initializeLocalAddresses = EventState.idle;
    performPhase1MappingTest = EventState.idle;
    performPhase2MappingTest = EventState.idle;
    performPhase3MappingTest = EventState.idle;
    performPhase1FilteringTest = EventState.idle;
    performPhase2FilteringTest = EventState.idle;
  }

  @override
  String toString() {
    return 'CheckerEvent{initializeLocalAddresses: $initializeLocalAddresses, performPhase1MappingTest: $performPhase1MappingTest, performPhase2MappingTest: $performPhase2MappingTest, performPhase3MappingTest: $performPhase3MappingTest, performPhase1FilteringTest: $performPhase1FilteringTest, performPhase2FilteringTest: $performPhase2FilteringTest}';
  }
}
