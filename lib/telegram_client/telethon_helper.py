#!/usr/bin/env python3
"""One-request JSON boundary for the Telegram user API.

Sensitive inputs and Telegram exception text intentionally never reach stderr.
"""

import asyncio
import json
import sys

import socks
from telethon import TelegramClient
from telethon.errors import SessionPasswordNeededError
from telethon.sessions import StringSession


def proxy_from(request):
    proxy = request.get("proxy")
    if not proxy:
        return None
    if proxy.get("scheme") != "socks5" or not proxy.get("host") or not proxy.get("port"):
        raise ValueError("invalid_proxy")
    values = [socks.SOCKS5, proxy["host"], int(proxy["port"]), True]
    if proxy.get("username"):
        values.append(proxy["username"])
        values.append(proxy.get("password"))
    return tuple(values)


def user_data(user):
    return {"id": user.id, "username": user.username, "first_name": user.first_name, "last_name": user.last_name}


async def execute(request):
    session = StringSession(request.get("session") or "")
    client = TelegramClient(session, int(request["api_id"]), request["api_hash"], proxy=proxy_from(request))
    try:
        await client.connect()
        operation = request.get("operation")
        if operation == "send_code":
            sent = await client.send_code_request(request["phone"])
            return {"success": True, "phone_code_hash": sent.phone_code_hash, "session": StringSession.save(client.session)}
        if operation == "confirm_code":
            try:
                user = await client.sign_in(request["phone"], request["code"], phone_code_hash=request["phone_code_hash"])
            except SessionPasswordNeededError:
                return {"success": False, "error_type": "needs_password"}
            return {"success": True, "session": StringSession.save(client.session), "user": user_data(user)}
        if operation == "get_me":
            user = await client.get_me()
            if user is None:
                return {"success": False, "error_type": "not_authorized"}
            return {"success": True, "user": user_data(user)}
        return {"success": False, "error_type": "invalid_operation"}
    finally:
        await client.disconnect()


def main():
    try:
        request = json.load(sys.stdin)
        response = asyncio.run(execute(request))
    except Exception as error:  # Telegram messages can contain sensitive input.
        response = {"success": False, "error_type": error.__class__.__name__}
    sys.stdout.write(json.dumps(response))


if __name__ == "__main__":
    main()
