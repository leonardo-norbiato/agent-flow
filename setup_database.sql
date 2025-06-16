-- =================================================================
-- SETUP COMPLETO DO BANCO DE DADOS - AGENT FLOW
-- =================================================================

-- EXTENSÕES NECESSÁRIAS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =================================================================
-- 1. TABELA DE PERFIS DE USUÁRIO
-- =================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT,
    full_name TEXT,
    avatar_url TEXT,
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS para profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- =================================================================
-- 2. TABELA PRINCIPAL DE FLOWS
-- =================================================================
CREATE TABLE IF NOT EXISTS public.flows (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL DEFAULT 'Untitled Flow',
    description TEXT DEFAULT '',
    graph_json JSONB DEFAULT '{"nodes": [], "edges": []}',
    is_public BOOLEAN DEFAULT FALSE,
    is_template BOOLEAN DEFAULT FALSE,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    version INTEGER DEFAULT 1,
    tags TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_flows_user_id ON public.flows(user_id);
CREATE INDEX IF NOT EXISTS idx_flows_status ON public.flows(status);
CREATE INDEX IF NOT EXISTS idx_flows_is_public ON public.flows(is_public);
CREATE INDEX IF NOT EXISTS idx_flows_tags ON public.flows USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_flows_updated_at ON public.flows(updated_at DESC);

-- RLS para flows
ALTER TABLE public.flows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own flows" ON public.flows
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view public flows" ON public.flows
    FOR SELECT USING (is_public = TRUE);

CREATE POLICY "Users can create their own flows" ON public.flows
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own flows" ON public.flows
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own flows" ON public.flows
    FOR DELETE USING (auth.uid() = user_id);

-- =================================================================
-- 3. TABELA DE EXECUÇÕES DE FLOWS
-- =================================================================
CREATE TABLE IF NOT EXISTS public.flow_executions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    flow_id UUID REFERENCES public.flows(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    input_data JSONB DEFAULT '{}',
    output_data JSONB DEFAULT '{}',
    execution_log JSONB DEFAULT '[]',
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed', 'cancelled')),
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    execution_time_ms INTEGER
);

-- Índices para execuções
CREATE INDEX IF NOT EXISTS idx_flow_executions_flow_id ON public.flow_executions(flow_id);
CREATE INDEX IF NOT EXISTS idx_flow_executions_user_id ON public.flow_executions(user_id);
CREATE INDEX IF NOT EXISTS idx_flow_executions_status ON public.flow_executions(status);
CREATE INDEX IF NOT EXISTS idx_flow_executions_started_at ON public.flow_executions(started_at DESC);

-- RLS para execuções
ALTER TABLE public.flow_executions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own executions" ON public.flow_executions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own executions" ON public.flow_executions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own executions" ON public.flow_executions
    FOR UPDATE USING (auth.uid() = user_id);

-- =================================================================
-- 4. TABELA DE CONFIGURAÇÕES DE API/CONEXÕES
-- =================================================================
CREATE TABLE IF NOT EXISTS public.user_connections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    service_name TEXT NOT NULL, -- ex: 'openai', 'anthropic', 'composio', etc.
    connection_type TEXT NOT NULL, -- 'api_key', 'oauth', 'custom'
    connection_data JSONB DEFAULT '{}', -- dados da conexão criptografados
    is_active BOOLEAN DEFAULT TRUE,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, service_name)
);

-- Índices para conexões
CREATE INDEX IF NOT EXISTS idx_user_connections_user_id ON public.user_connections(user_id);
CREATE INDEX IF NOT EXISTS idx_user_connections_service ON public.user_connections(service_name);

-- RLS para conexões
ALTER TABLE public.user_connections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own connections" ON public.user_connections
    FOR ALL USING (auth.uid() = user_id);

-- =================================================================
-- 5. TABELA DE TEMPLATES PÚBLICOS
-- =================================================================
CREATE TABLE IF NOT EXISTS public.flow_templates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    graph_json JSONB NOT NULL DEFAULT '{"nodes": [], "edges": []}',
    preview_image_url TEXT,
    creator_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    is_featured BOOLEAN DEFAULT FALSE,
    use_count INTEGER DEFAULT 0,
    tags TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para templates
CREATE INDEX IF NOT EXISTS idx_flow_templates_category ON public.flow_templates(category);
CREATE INDEX IF NOT EXISTS idx_flow_templates_featured ON public.flow_templates(is_featured);
CREATE INDEX IF NOT EXISTS idx_flow_templates_tags ON public.flow_templates USING GIN(tags);

-- RLS para templates (apenas leitura pública)
ALTER TABLE public.flow_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Everyone can view templates" ON public.flow_templates
    FOR SELECT TO authenticated USING (true);

-- =================================================================
-- 6. TABELA DE COMPARTILHAMENTOS
-- =================================================================
CREATE TABLE IF NOT EXISTS public.flow_shares (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    flow_id UUID REFERENCES public.flows(id) ON DELETE CASCADE NOT NULL,
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    shared_with_email TEXT,
    shared_with_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    permission_level TEXT DEFAULT 'view' CHECK (permission_level IN ('view', 'edit', 'admin')),
    share_token UUID DEFAULT gen_random_uuid() UNIQUE,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para compartilhamentos
CREATE INDEX IF NOT EXISTS idx_flow_shares_flow_id ON public.flow_shares(flow_id);
CREATE INDEX IF NOT EXISTS idx_flow_shares_owner_id ON public.flow_shares(owner_id);
CREATE INDEX IF NOT EXISTS idx_flow_shares_shared_with ON public.flow_shares(shared_with_user_id);

-- RLS para compartilhamentos
ALTER TABLE public.flow_shares ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage shares for their flows" ON public.flow_shares
    FOR ALL USING (auth.uid() = owner_id);

CREATE POLICY "Users can view shares made to them" ON public.flow_shares
    FOR SELECT USING (auth.uid() = shared_with_user_id);

-- =================================================================
-- FUNÇÕES E TRIGGERS
-- =================================================================

-- Função para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers para updated_at
CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_flows_updated_at 
    BEFORE UPDATE ON public.flows
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_connections_updated_at 
    BEFORE UPDATE ON public.user_connections
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_flow_templates_updated_at 
    BEFORE UPDATE ON public.flow_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =================================================================
-- FUNÇÃO PARA CRIAR PERFIL AUTOMATICAMENTE
-- =================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email)
    );
    RETURN NEW;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- Trigger para criar perfil quando novo usuário se registra
CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =================================================================
-- VIEWS ÚTEIS
-- =================================================================

-- View para flows com informações do criador
CREATE OR REPLACE VIEW public.flows_with_creator AS
SELECT 
    f.*,
    p.full_name as creator_name,
    p.avatar_url as creator_avatar
FROM public.flows f
LEFT JOIN public.profiles p ON f.user_id = p.id;

-- View para estatísticas de usuário
CREATE OR REPLACE VIEW public.user_stats AS
SELECT 
    p.id,
    p.full_name,
    COUNT(f.id) as total_flows,
    COUNT(CASE WHEN f.is_public THEN 1 END) as public_flows,
    COUNT(fe.id) as total_executions,
    MAX(f.updated_at) as last_flow_update
FROM public.profiles p
LEFT JOIN public.flows f ON p.id = f.user_id
LEFT JOIN public.flow_executions fe ON p.id = fe.user_id
GROUP BY p.id, p.full_name;

-- =================================================================
-- DADOS INICIAIS/TEMPLATES
-- =================================================================

-- Inserir alguns templates básicos (opcional)
INSERT INTO public.flow_templates (name, description, category, graph_json, is_featured, tags) VALUES
('Simple Chat Bot', 'A basic chatbot flow using LLM', 'AI Assistant', '{"nodes": [{"id": "input", "type": "inputNode", "position": {"x": 100, "y": 100}}, {"id": "llm", "type": "llmNode", "position": {"x": 300, "y": 100}}, {"id": "output", "type": "outputNode", "position": {"x": 500, "y": 100}}], "edges": [{"id": "e1", "source": "input", "target": "llm"}, {"id": "e2", "source": "llm", "target": "output"}]}', true, ARRAY['chatbot', 'llm', 'basic']),
('Data Analysis Flow', 'Analyze data using AI tools', 'Data Science', '{"nodes": [{"id": "input", "type": "inputNode", "position": {"x": 100, "y": 100}}, {"id": "composio", "type": "composioNode", "position": {"x": 300, "y": 100}}, {"id": "llm", "type": "llmNode", "position": {"x": 500, "y": 100}}, {"id": "output", "type": "outputNode", "position": {"x": 700, "y": 100}}], "edges": [{"id": "e1", "source": "input", "target": "composio"}, {"id": "e2", "source": "composio", "target": "llm"}, {"id": "e3", "source": "llm", "target": "output"}]}', true, ARRAY['data', 'analysis', 'composio'])
ON CONFLICT DO NOTHING;

-- =================================================================
-- COMENTÁRIOS E DOCUMENTAÇÃO
-- =================================================================

COMMENT ON TABLE public.profiles IS 'Perfis de usuário com informações adicionais';
COMMENT ON TABLE public.flows IS 'Tabela principal para armazenar flows criados pelos usuários';
COMMENT ON TABLE public.flow_executions IS 'Histórico de execuções de flows';
COMMENT ON TABLE public.user_connections IS 'Configurações de conexão com APIs externas';
COMMENT ON TABLE public.flow_templates IS 'Templates públicos de flows';
COMMENT ON TABLE public.flow_shares IS 'Compartilhamentos de flows entre usuários';

-- =================================================================
-- FIM DO SETUP
-- =================================================================