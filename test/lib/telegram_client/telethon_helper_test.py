import importlib.util
import pathlib
import unittest


HELPER_PATH = pathlib.Path(__file__).resolve().parents[3] / "lib/telegram_client/telethon_helper.py"
SPEC = importlib.util.spec_from_file_location("telethon_helper", HELPER_PATH)
helper = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(helper)


class TelethonHelperTest(unittest.TestCase):
    def test_proxy_and_normalized_public_channel(self):
        proxy = helper.proxy_from({"proxy": {"scheme": "socks5", "host": "proxy.example", "port": 1080}})
        self.assertEqual(proxy[1:4], ("proxy.example", 1080, True))

        channel = type("Channel", (), {"id": 99, "access_hash": 123, "username": "public_news", "title": "Public news"})()
        self.assertEqual(
            helper.channel_data(channel),
            {"id": 99, "access_hash": "123", "username": "public_news", "title": "Public news"},
        )

    def test_normalizes_messages_and_sanitizes_flood_wait(self):
        message = type("Message", (), {"id": 17, "date": __import__("datetime").datetime(2026, 8, 26, 10, 0), "message": "hello", "views": 12, "forwards": None})()
        self.assertEqual(
            helper.message_data(message),
            {"id": 17, "date": "2026-08-26T10:00:00Z", "text": "hello", "views": 12, "forwards": None},
        )
        original = helper.FloodWaitError
        try:
            helper.FloodWaitError = type("FloodWaitError", (Exception,), {"seconds": 999999})
            self.assertEqual(helper.error_response(helper.FloodWaitError()), {"success": False, "error_type": "flood_wait", "retry_after": 86400})
        finally:
            helper.FloodWaitError = original


if __name__ == "__main__":
    unittest.main()
