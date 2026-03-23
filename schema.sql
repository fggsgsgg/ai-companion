-- AI 陪伴应用 - Supabase 数据库 Schema
-- 用于生产环境的云同步（MVP 版本使用 localStorage）

-- 用户表
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  plan TEXT DEFAULT 'free' CHECK (plan IN ('free', 'pro')),
  stripe_customer_id TEXT
);

-- AI 角色设置
CREATE TABLE IF NOT EXISTS user_settings (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  avatar TEXT DEFAULT '',
  name TEXT DEFAULT '小暖',
  user_title TEXT DEFAULT '亲爱的',
  style TEXT DEFAULT 'gentle',
  style_description TEXT DEFAULT '温柔体贴，善解人意',
  catchphrases TEXT[] DEFAULT ARRAY['嗯嗯~', '好哒', '想你了'],
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 示例文案文件夹
CREATE TABLE IF NOT EXISTS example_folders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 示例对话内容
CREATE TABLE IF NOT EXISTS example_chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  folder_id UUID NOT NULL REFERENCES example_folders(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 聊天记录
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  is_proactive BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 主动聊天设置
CREATE TABLE IF NOT EXISTS schedule_settings (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  enabled BOOLEAN DEFAULT FALSE,
  start_time TEXT DEFAULT '08:00',
  end_time TEXT DEFAULT '22:00',
  frequency INTEGER DEFAULT 60,
  topics TEXT[] DEFAULT ARRAY['日常问候', '关心提醒'],
  last_proactive_time TIMESTAMPTZ
);

-- 消息配额
CREATE TABLE IF NOT EXISTS message_quotas (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  count INTEGER DEFAULT 0
);

-- 付费记录
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  plan TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  stripe_session_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_chat_messages_user ON chat_messages(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_example_folders_user ON example_folders(user_id);
CREATE INDEX IF NOT EXISTS idx_example_chats_folder ON example_chats(folder_id);
CREATE INDEX IF NOT EXISTS idx_message_quotas_user_date ON message_quotas(user_id, date);

-- RLS 策略
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE example_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE example_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedule_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- 用户只能访问自己的数据
CREATE POLICY "Users can view own data" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own data" ON users FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Settings for owner" ON user_settings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Folders for owner" ON example_folders FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Chats for folder owner" ON example_chats FOR ALL USING (
  folder_id IN (SELECT id FROM example_folders WHERE user_id = auth.uid())
);
CREATE POLICY "Messages for owner" ON chat_messages FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Schedule for owner" ON schedule_settings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Quota for owner" ON message_quotas FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Payments for owner" ON payments FOR ALL USING (auth.uid() = user_id);
