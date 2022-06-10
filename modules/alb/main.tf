resource "aws_lb_target_group" "target-group-1" {
  health_check {
    interval            = 120
    path                = "/"
    protocol            = "HTTP"
    timeout             = 100
    healthy_threshold   = 5
    unhealthy_threshold = 3
  }

  name        = "${var.project}-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id
}

resource "aws_lb" "alb-1" {
  name     = "${var.project}-alb"
  internal = false

  security_groups = [
    var.security_group_id,
  ]

  subnets = var.subnet_id

  tags = {
    Name = "${var.project}-alb"
  }

  ip_address_type    = "ipv4"
  load_balancer_type = "application"
}

resource "aws_lb_listener" "alb-listner-1" {
  load_balancer_arn = aws_lb.alb-1.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group-1.arn
  }
}

resource "aws_acm_certificate" "default" {
  domain_name       = "tasucu.click"
  validation_method = "DNS"
}

data "aws_route53_zone" "external" {
  name = "tasucu.click"
}

resource "aws_route53_record" "validation" {
  allow_overwrite = true
  name    = tolist(aws_acm_certificate.default.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.default.domain_validation_options)[0].resource_record_type
  zone_id = data.aws_route53_zone.external.zone_id
  records = [ tolist(aws_acm_certificate.default.domain_validation_options)[0].resource_record_value ]
  ttl     = "60"
}

resource "aws_acm_certificate_validation" "default" {
  certificate_arn = "${aws_acm_certificate.default.arn}"

  validation_record_fqdns = [
    "${aws_route53_record.validation.fqdn}",
  ]
}

resource "aws_route53_record" "record-1" {
  zone_id = "Z0864870176T1RW93BUL9"
  name    = "tasucu.click"
  type    = "A"

  alias {
    name                   = aws_lb.alb-1.dns_name
    zone_id                = aws_lb.alb-1.zone_id
    evaluate_target_health = true
  }
}

#for HTTPS
resource "aws_lb_listener" "alb-listner-2" {
  load_balancer_arn = aws_lb.alb-1.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  certificate_arn   = "${aws_acm_certificate.default.arn}"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group-1.arn
  }
}
