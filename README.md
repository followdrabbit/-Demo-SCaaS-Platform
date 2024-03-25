# SCaaS Platform

![Demonstração do SCaaS](assets/scaas_test.gif)

Este repositório contém a demonstração de como criar um serviço automatizado que recebe chamadas de API para realizar ações específicas.

## Objetivo

O objetivo desta demonstração é processar uma chamada de API contendo o ID de uma Imagem de Máquina da Amazon (AMI) e executar as seguintes ações:

1. Validar se o JSON está dentro da estrutura correta.
2. Verificar se a AMI especificada existe.
3. Iniciar uma instância EC2 do tipo `t2.micro` utilizando a AMI fornecida, sem atribuir um IP público.

## Implementação

O código necessário para reproduzir esta demonstração está disponível no arquivo `main.tf` do Terraform, localizado neste repositório.