**Date:** 2025-04-02<br/>
**Author:** Pietro Pasotti (@ppasotti)  

## Context and Problem Statement

Some of our charms (`parca-k8s`, `[tempo|loki|mimir]-coordinator-k8s`) have adopted 
a 'holistic' reconciler pattern, implemented as:

```python
class MyCharm:
    def __init__(self, *_):
        self.reconcile()

    def reconcile(self):
        ...
```

This is un-charmy as it breaks out of the event-driven framework box, and that has resulted in 
subtle bugs in the past, because we're accessing things at a point in time when the framework 
isn't ready to expose them to us. Read: the framework assumes that all hook tool calls are made
within an event context, but the framework only sets up the event context within the scope of an 
event emission; and by calling `reconcile()` in the charm's init, we might break that assumption.


## Decision 

We hereby decide to adopt and roll out the following pattern instead:

```python
import ops 

class Reconciler(ops.Object):
    """Helper class to listen to all hook events but only run the handler once."""

    def __init__(self, parent, callback):
        super().__init__(parent, "reconciler")
        # without this has_run check, deferred events will trigger the callback as well,
        # resulting in multiple executions.
        # normally holistic charms don't defer, but this will help non-holistic charms
        # to adopt the reconciler without having to ditch all their defers first.
        self._has_run = False

        self.callback = callback
        for event in filter(lambda e: issubclass(e.event_type, ops.HookEvent),
                            self.on.events().values()):
            self.framework.observe(event, self._on_any_event)

    def _on_any_event(self, _:ops.EventBase):
        if not self._has_run:
            self.callback()
            self._has_run = True

class MyCharm(ops.CharmBase):
    def __init__(self, framework):
        super().__init__(framework)
        self._reconciler = Reconciler(self, callback=self.reconcile)

    def reconcile(self):
        ...
```

demo implementation: https://github.com/canonical/parca-k8s-operator/blob/demo-reconciler-object/src/charm.py#L72

## Benefits

- Less friction with the framework
- No side-effecting in the constructor

## Disadvantages

- lot of stuff to copy paste around our charms
- somewhat hard to get it right

to mitigate, we could put this in a library?

## Alternatives considered

- Business as usual
