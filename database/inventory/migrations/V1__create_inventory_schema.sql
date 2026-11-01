
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE item_estoque (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 codigo VARCHAR(100) NOT NULL UNIQUE,
 nome VARCHAR(150) NOT NULL,
 descricao VARCHAR(255),
 tipo_item VARCHAR(50) NOT NULL,
 unidade_medida VARCHAR(50) NOT NULL,
 quantidade_estoque INTEGER NOT NULL DEFAULT 0 CHECK (quantidade_estoque >= 0),
 custo_unitario NUMERIC(10,2) NOT NULL CHECK (custo_unitario > 0),
 preco_venda NUMERIC(10,2) NOT NULL CHECK (preco_venda > 0),
 estoque_minimo INTEGER NOT NULL DEFAULT 0 CHECK (estoque_minimo >= 0),
 marca VARCHAR(100), veiculo_aplicavel VARCHAR(255),
 ativo BOOLEAN NOT NULL DEFAULT TRUE,
 created_at TIMESTAMP NOT NULL DEFAULT now(),
 updated_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TABLE movimentacao_estoque (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 id_item_estoque UUID NOT NULL REFERENCES item_estoque(id),
 tipo_movimentacao VARCHAR(20) NOT NULL CHECK (tipo_movimentacao IN ('ENTRADA','BAIXA','AJUSTE')),
 origem_movimentacao VARCHAR(50) NOT NULL CHECK (origem_movimentacao IN ('MANUAL','ORDEM_SERVICO','COMPRA')),
 referencia_origem_id UUID,
 quantidade_antes INTEGER NOT NULL CHECK (quantidade_antes >= 0),
 quantidade_depois INTEGER NOT NULL CHECK (quantidade_depois >= 0),
 observacao VARCHAR(500),
 usuario_responsavel_id UUID NOT NULL,
 created_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX idx_movimentacao_item ON movimentacao_estoque(id_item_estoque,created_at DESC);
