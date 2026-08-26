#!/usr/bin/env python3
"""One-request JSON boundary for the Telegram user API.

Sensitive inputs and Telegram exception text intentionally never reach stderr.
"""

import asyncio
import json
import sys

import socks
from telethon import TelegramClient
from telethon.errors import (
    AuthKeyUnregisteredError,
    ChannelPrivateError,
    FloodWaitError,
    RPCError,
    SessionPasswordNeededError,
    SessionRevokedError,
    UsernameInvalidError,
    UsernameNotOccupiedError,
    UserAlreadyParticipantError,
    UserDeactivatedBanError,
)
from telethon.sessions import StringSession
from telethon.tl.functions.auth import ResendCodeRequest
from telethon.tl.functions.channels import JoinChannelRequest
from telethon.tl.types import Channel, InputPeerChannel

MAX_BATCH_SIZE = 100
MAX_RETRY_AFTER = 86_400


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


def channel_data(channel):
    return {
        "id": channel.id,
        "access_hash": str(channel.access_hash),
        "username": channel.username,
        "title": channel.title,
    }


def message_data(message):
    date = message.date
    if date.tzinfo is None:
        date = date.replace(tzinfo=__import__("datetime").timezone.utc)
    return {
        "id": message.id,
        "date": date.astimezone(__import__("datetime").timezone.utc).isoformat().replace("+00:00", "Z"),
        "text": message.message,
        "views": message.views,
        "forwards": message.forwards,
    }


def error_response(error):
    if isinstance(error, FloodWaitError):
        return {"success": False, "error_type": "flood_wait", "retry_after": min(max(int(error.seconds), 1), MAX_RETRY_AFTER)}
    if isinstance(error, ChannelPrivateError):
        return {"success": False, "error_type": "private_channel"}
    if isinstance(error, (UsernameInvalidError, UsernameNotOccupiedError, ValueError)):
        return {"success": False, "error_type": "invalid_username"}
    if isinstance(error, (AuthKeyUnregisteredError, SessionRevokedError, UserDeactivatedBanError)):
        return {"success": False, "error_type": "not_authorized"}
    return {"success": False, "error_type": "request_failed"}


async def authorized(client):
    if not await client.is_user_authorized():
        return {"success": False, "error_type": "not_authorized"}
    return None


async def public_channel(client, username):
    if not isinstance(username, str) or not username.startswith("@") or not username[1:].replace("_", "").isalnum():
        raise ValueError("invalid_username")
    channel = await client.get_entity(username)
    if not isinstance(channel, Channel) or not channel.username:
        raise ValueError("invalid_username")
    return channel


def channel_from_request(request):
    channel = request.get("channel") or {}
    try:
        return InputPeerChannel(int(channel["id"]), int(channel["access_hash"]))
    except (KeyError, TypeError, ValueError):
        raise ValueError("invalid_username")


async def join_public_channel(client, channel):
    try:
        await client(JoinChannelRequest(channel))
    except UserAlreadyParticipantError:
        return None


async def execute(request):
    session = StringSession(request.get("session") or "")
    client = TelegramClient(session, int(request["api_id"]), request["api_hash"], proxy=proxy_from(request))
    try:
        await client.connect()
        operation = request.get("operation")
        if operation == "send_code":
            sent = await client.send_code_request(request["phone"])
            return {"success": True, "phone_code_hash": sent.phone_code_hash, "session": StringSession.save(client.session), "delivery_type": sent.type.__class__.__name__}
        if operation == "resend_code":
            sent = await client(ResendCodeRequest(request["phone"], request["phone_code_hash"]))
            return {"success": True, "phone_code_hash": sent.phone_code_hash, "session": StringSession.save(client.session), "delivery_type": sent.type.__class__.__name__}
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
        authorization_error = await authorized(client)
        if authorization_error:
            return authorization_error
        if operation == "resolve_channel":
            return {"success": True, "channel": channel_data(await public_channel(client, request.get("username")))}
        if operation == "join_channel":
            channel = await public_channel(client, request.get("username"))
            await join_public_channel(client, channel)
            return {"success": True, "channel": channel_data(channel)}
        if operation == "read_channel_messages":
            limit = int(request.get("limit", 50))
            if not 1 <= limit <= MAX_BATCH_SIZE:
                raise ValueError("invalid_username")
            after_message_id = request.get("after_message_id")
            after_date = request.get("after_date")
            if after_date:
                after_date = __import__("datetime").datetime.fromisoformat(after_date.replace("Z", "+00:00"))
            messages = []
            async for message in client.iter_messages(channel_from_request(request), limit=limit):
                if message is None or message.date is None:
                    continue
                if after_message_id is not None and message.id <= int(after_message_id):
                    continue
                if after_date and message.date <= after_date:
                    continue
                messages.append(message_data(message))
            return {"success": True, "messages": messages}
        return {"success": False, "error_type": "invalid_operation"}
    except (ChannelPrivateError, FloodWaitError, UsernameInvalidError, UsernameNotOccupiedError, AuthKeyUnregisteredError,
            SessionRevokedError, UserDeactivatedBanError, RPCError, OSError, TimeoutError, ValueError) as error:
        return error_response(error)
    finally:
        await client.disconnect()


def main():
    try:
        request = json.load(sys.stdin)
        response = asyncio.run(execute(request))
    except Exception as error:  # Telegram messages can contain sensitive input.
        response = error_response(error)
    sys.stdout.write(json.dumps(response))


if __name__ == "__main__":
    main()
