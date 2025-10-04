# Конфигурация Telegram Bot
# Документация: https://github.com/telegram-bot-rb/telegram-bot

if Rails.env.test?
  Telegram.reset_bots
  Telegram::Bot::ClientStub.stub_all!
  # Важно чтобы bots_config шел ПОСЛЕ reset_bots
  Telegram.bots_config = {
    default: {
      token: 'test_token',
      username: 'test_bot'
    }
  }
else
  Telegram.bots_config = {
    default: {
      token: ApplicationConfig.bot_token,
      username: ApplicationConfig.bot_username # опционально
    }
  }
end
