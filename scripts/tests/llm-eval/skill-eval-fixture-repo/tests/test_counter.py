from counter import incr


def test_counter():
    assert incr(2) == 2
    assert incr(1) == 3
