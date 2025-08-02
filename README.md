# Public Transit Accessibility and Service Quality Platform

A blockchain-based platform for monitoring and ensuring public transit accessibility, service quality, and equity across urban transportation networks.

## Overview

This platform consists of five interconnected smart contracts that work together to create a comprehensive transit monitoring and compliance system:

1. **Wheelchair Accessibility Compliance** - Ensures all transit vehicles and stations meet ADA requirements
2. **Service Reliability Monitoring** - Tracks on-time performance and service disruptions
3. **Fare Equity Analysis** - Evaluates transit pricing for affordability and equity
4. **Route Coverage Assessment** - Analyzes transit route coverage across neighborhoods
5. **Customer Complaint Resolution** - Manages passenger feedback and complaint resolution

## Key Features

### Accessibility Compliance
- Vehicle wheelchair accessibility tracking
- Station accessibility audits
- Compliance scoring and reporting
- Violation tracking and remediation

### Service Reliability
- Real-time on-time performance monitoring
- Service disruption logging
- Route reliability scoring
- Historical performance analytics

### Fare Equity
- Income-based fare analysis
- Affordability assessments
- Equity scoring across demographics
- Subsidy program tracking

### Route Coverage
- Neighborhood service coverage analysis
- Population density vs. service frequency
- Underserved area identification
- Coverage equity scoring

### Complaint Resolution
- Decentralized complaint submission
- Transparent resolution tracking
- Response time monitoring
- Satisfaction scoring

## Contract Architecture

Each contract operates independently while maintaining data integrity and transparency. The platform uses Clarity's native data structures and functions for optimal performance and security.

### Data Types

- \`uint\` for scores, counts, and timestamps
- \`principal\` for user and authority identification
- \`string-ascii\` for descriptions and identifiers
- \`bool\` for status flags and compliance indicators

### Access Control

- Transit authorities can update service data
- Auditors can submit compliance reports
- Public can submit complaints and view transparency data
- Contract owners manage system parameters

## Getting Started

### Prerequisites

- Clarinet CLI
- Node.js 18+
- Vitest for testing

### Installation

\`\`\`bash
npm install
clarinet check
\`\`\`

### Testing

\`\`\`bash
npm test
\`\`\`

### Deployment

\`\`\`bash
clarinet deploy
\`\`\`

## Usage Examples

### Submit Accessibility Report
\`\`\`clarity
(contract-call? .accessibility-compliance submit-accessibility-report
"vehicle-001"
true
u95
"Wheelchair lift operational, priority seating available")
\`\`\`

### Log Service Disruption
\`\`\`clarity
(contract-call? .service-reliability log-service-disruption
"route-42"
u1640995200
u30
"Signal malfunction causing delays")
\`\`\`

### Submit Complaint
\`\`\`clarity
(contract-call? .complaint-resolution submit-complaint
"accessibility"
u3
"Elevator out of service at downtown station")
\`\`\`

## Governance

The platform supports decentralized governance through:
- Community voting on service standards
- Transparent reporting mechanisms
- Public access to performance data
- Stakeholder participation in policy decisions

## Security Features

- Input validation on all public functions
- Access control for sensitive operations
- Immutable audit trails
- Transparent scoring algorithms

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request with detailed description

## License

MIT License - see LICENSE file for details
