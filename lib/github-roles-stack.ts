import * as cdk from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export interface GitHubRepoConfig {
  owner: string;
  name: string;
  environments?: string[];
  branches?: string[];
}

export interface GitHubRolesStackProps extends cdk.StackProps {
  oidcProvider: iam.OpenIdConnectProvider;
  repositories: GitHubRepoConfig[];
  mgmtAccountRoleArn?: string;
}

export class GitHubRolesStack extends cdk.Stack {
  public readonly roleArns: Record<string, string> = {};

  constructor(scope: Construct, id: string, props: GitHubRolesStackProps) {
    super(scope, id, props);

    const { oidcProvider, repositories } = props;

    // Create roles for each repository
    repositories.forEach((repo) => {
      const roleName = `github-${repo.owner}-${repo.name}`;

      // Build the conditions for the role trust policy
      const conditions: Record<string, any> = {
        StringEquals: {
          'token.actions.githubusercontent.com:aud': 'sts.amazonaws.com',
        },
      };

      // Scope by repository
      const repoCondition = `repo:${repo.owner}/${repo.name}:*`;
      conditions['StringLike'] = conditions['StringLike'] || {};
      conditions['StringLike']['token.actions.githubusercontent.com:sub'] = repoCondition;

      // Create the role
      const role = new iam.Role(this, `GitHubRole-${repo.name}`, {
        roleName,
        assumedBy: new iam.OpenIdConnectPrincipal(oidcProvider, conditions),
        description: `OIDC role for GitHub repository ${repo.owner}/${repo.name}`,
      });

      // Add inline policy for basic assume role permissions
      // This allows the workflow to assume other roles if needed
      role.addInlinePolicy(
        new iam.Policy(this, `AssumeRolePolicy-${repo.name}`, {
          statements: [
            new iam.PolicyStatement({
              effect: iam.Effect.ALLOW,
              actions: ['sts:AssumeRole'],
              resources: ['arn:aws:iam::*:role/github-*'],
            }),
          ],
        })
      );

      // Store the role ARN
      this.roleArns[repo.name] = role.roleArn;

      // Output the role ARN
      new cdk.CfnOutput(this, `RoleArn-${repo.name}`, {
        value: role.roleArn,
        description: `OIDC role ARN for ${repo.owner}/${repo.name}`,
        exportName: `GitHubRoleArn-${repo.owner}-${repo.name}`,
      });
    });
  }
}
