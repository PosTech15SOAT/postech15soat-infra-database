# DER — Modelo de Dados NumberOne

Este documento representa o modelo relacional atualmente versionado na branch `develop`, com base na migration `database/migrations/V1__create_initial_schema.sql`.

## Diagrama Entidade-Relacionamento

```mermaid
erDiagram
    ADMIN_USERS {
        uuid id PK
        varchar username UK
        varchar password_hash
        varchar role
        boolean enabled
        timestamp created_at
    }

    CLIENTE {
        uuid id PK
        varchar nome
        varchar documento
        varchar tipo_documento
        varchar email
        varchar telefone
        varchar endereco
        boolean ativo
        timestamp created_at
        timestamp updated_at
    }

    VEICULO {
        uuid id PK
        uuid id_cliente FK
        varchar placa UK
        varchar marca
        varchar modelo
        integer ano
        timestamp created_at
        timestamp updated_at
    }

    SERVICO_AUTOMOTIVO {
        uuid id PK
        varchar codigo
        varchar nome
        varchar descricao
        varchar tipo_servico
        numeric valor_base
        integer tempo_estimado_minutos
        boolean ativo
        timestamp created_at
        timestamp updated_at
    }

    ITEM_ESTOQUE {
        uuid id PK
        varchar codigo
        varchar nome
        varchar descricao
        varchar tipo_item
        varchar unidade_medida
        integer quantidade_estoque
        numeric custo_unitario
        numeric preco_venda
        integer estoque_minimo
        varchar marca
        varchar veiculo_aplicavel
        boolean ativo
        timestamp created_at
        timestamp updated_at
    }

    MOVIMENTACAO_ESTOQUE {
        uuid id PK
        uuid id_item_estoque FK
        varchar tipo_movimentacao
        varchar origem_movimentacao
        uuid referencia_origem_id
        integer quantidade_antes
        integer quantidade_depois
        varchar motivo
        text observacao
        uuid usuario_responsavel_id
        timestamp created_at
    }

    ORDEM_SERVICO {
        uuid id PK
        uuid id_cliente FK
        uuid id_veiculo FK
        varchar descricao_inicial
        varchar descricao_diagnostico
        varchar descricao_diagnostico_final
        varchar observacao
        varchar status
        timestamp data_hora_entrada
        timestamp data_hora_prevista
        timestamp data_hora_entrega
        timestamp created_at
        timestamp updated_at
    }

    ORDEM_SERVICO_ORCAMENTO {
        uuid id PK
        uuid id_ordem_servico FK
        numeric valor_proposto
        numeric valor_aprovado
        varchar status
        timestamp enviado_em
        timestamp aprovado_em
        timestamp created_at
        timestamp updated_at
    }

    ORDEM_SERVICO_SERVICO {
        uuid id PK
        uuid id_ordem_servico FK
        uuid id_servico FK
        numeric valor
        varchar status
        boolean opcional
        timestamp data_hora_inicio
        timestamp data_hora_fim
        timestamp created_at
        timestamp updated_at
    }

    ORDEM_SERVICO_SERVICO_ITEM {
        uuid id PK
        uuid id_ordem_servico_servico FK
        uuid id_item_estoque FK
        bigint quantidade_usada
        timestamp created_at
        timestamp updated_at
    }

    CLIENTE o|--o{ VEICULO : possui
    CLIENTE o|--o{ ORDEM_SERVICO : solicita
    VEICULO o|--o{ ORDEM_SERVICO : vinculado_a

    ORDEM_SERVICO ||--o{ ORDEM_SERVICO_ORCAMENTO : possui
    ORDEM_SERVICO ||--o{ ORDEM_SERVICO_SERVICO : contem

    SERVICO_AUTOMOTIVO o|--o{ ORDEM_SERVICO_SERVICO : referencia

    ORDEM_SERVICO_SERVICO ||--o{ ORDEM_SERVICO_SERVICO_ITEM : consome
    ITEM_ESTOQUE o|--o{ ORDEM_SERVICO_SERVICO_ITEM : utilizado_em

    ITEM_ESTOQUE ||--o{ MOVIMENTACAO_ESTOQUE : movimenta