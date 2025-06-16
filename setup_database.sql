-- Criar tabela flows
CREATE TABLE IF NOT EXISTS flows (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL DEFAULT 'Untitled Flow',
    description TEXT DEFAULT '',
    graph_json JSONB DEFAULT '{"nodes": [], "edges": []}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habilitar RLS (Row Level Security)
ALTER TABLE flows ENABLE ROW LEVEL SECURITY;

-- Política para usuários só verem seus próprios flows
CREATE POLICY "Users can view their own flows" ON flows
    FOR SELECT USING (auth.uid() = user_id);

-- Política para usuários criarem flows
CREATE POLICY "Users can create their own flows" ON flows
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Política para usuários atualizarem seus próprios flows
CREATE POLICY "Users can update their own flows" ON flows
    FOR UPDATE USING (auth.uid() = user_id);

-- Política para usuários deletarem seus próprios flows
CREATE POLICY "Users can delete their own flows" ON flows
    FOR DELETE USING (auth.uid() = user_id);

-- Função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar updated_at
CREATE TRIGGER update_flows_updated_at BEFORE UPDATE ON flows
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();