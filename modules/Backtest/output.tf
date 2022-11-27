output "backtest1_Arn" {
    value = aws_lambda_function.lambda1.qualified_arn
}

output "backtest2_Arn" {
    value = aws_lambda_function.lambda2.qualified_arn
}