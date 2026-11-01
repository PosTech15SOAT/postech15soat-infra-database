
-- Saldo disponível = quantidade_estoque - reservas ATIVAS.
CREATE TABLE reserva_estoque (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 ordem_servico_id UUID NOT NULL,
 correlation_id UUID,
 status VARCHAR(20) NOT NULL DEFAULT 'ATIVA'
 CHECK (status IN ('ATIVA','CONSUMIDA','LIBERADA','EXPIRADA')),
 expires_at TIMESTAMPTZ,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_reserva_ativa_os ON reserva_estoque(ordem_servico_id) WHERE status='ATIVA';
CREATE TABLE reserva_estoque_item (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 reserva_id UUID NOT NULL REFERENCES reserva_estoque(id),
 item_estoque_id UUID NOT NULL REFERENCES item_estoque(id),
 quantidade INTEGER NOT NULL CHECK (quantidade > 0),
 UNIQUE(reserva_id,item_estoque_id)
);
CREATE INDEX idx_reserva_item ON reserva_estoque_item(item_estoque_id);
CREATE TABLE processed_message (
 message_id VARCHAR(255) PRIMARY KEY,
 message_type VARCHAR(100) NOT NULL,
 processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE outbox_event (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 event_type VARCHAR(100) NOT NULL,
 aggregate_id UUID NOT NULL,
 correlation_id UUID,
 payload JSONB NOT NULL,
 status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','PUBLISHED')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 published_at TIMESTAMPTZ
);
CREATE INDEX idx_outbox_pending ON outbox_event(created_at) WHERE status='PENDING';
