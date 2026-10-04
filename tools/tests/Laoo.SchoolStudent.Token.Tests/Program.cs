using System.IdentityModel.Tokens.Jwt;
using System.Security.Cryptography;
using System.Text;
using LaooApi.Models;
using LaooApi.Security;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

var key=Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
var options=new JwtOptions{Issuer="school-student-test",Audience="test",SecretKey=key,AccessTokenMinutes=5};
var service=new JwtTokenService(Options.Create(options));
var handler=new JwtSecurityTokenHandler();
var baseline=new AuthenticatedUser("company:1","COMPANY_USER","COMPANY",null,null,1,1,1,null,1,"LAOO","fixture","Fixture",false);
var count=0;
void Check(string name,bool condition){if(!condition)throw new Exception(name);count++;Console.WriteLine("PASS "+name);}
void Reject(string name,AuthenticatedUser user){try{service.CreateToken(user);}catch(ArgumentException){Check(name,true);return;}throw new Exception(name);}
JwtSecurityToken Read(AuthenticatedUser user){
    var result=service.CreateToken(user);
    handler.ValidateToken(result.AccessToken,new TokenValidationParameters{
        ValidateIssuer=true,ValidIssuer=options.Issuer,ValidateAudience=true,ValidAudience=options.Audience,
        ValidateIssuerSigningKey=true,IssuerSigningKey=new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
        ValidateLifetime=true,ClockSkew=TimeSpan.Zero},out var token);
    return (JwtSecurityToken)token;
}
var company=Read(baseline);
Check("company token unchanged",company.Claims.Any(c=>c.Type=="user_id"&&c.Value=="1")&&!company.Claims.Any(c=>c.Type is "student_id" or "credential_version"));
var guardian=Read(baseline with {UserType="SCHOOL_GUARDIAN",UserId=null,GuardianId=2});
Check("guardian token unchanged",guardian.Claims.Any(c=>c.Type=="guardian_id"&&c.Value=="2")&&!guardian.Claims.Any(c=>c.Type=="student_id"));
var student=baseline with {UserType="SCHOOL_STUDENT",LoginMode="SCHOOL_STUDENT",ProjectCode="LAOO_SCHOOL_FOOD",UserId=null,StudentId=3,CredentialVersion=7};
var token=Read(student);
Check("student identity claim",token.Claims.Any(c=>c.Type=="student_id"&&c.Value=="3"));
Check("student credential version",token.Claims.Any(c=>c.Type=="credential_version"&&c.Value=="7"));
Check("student cannot inherit company user identity",!token.Claims.Any(c=>c.Type is "user_id" or "guardian_id"));
Reject("student id required",student with {StudentId=null});
Reject("credential version required",student with {CredentialVersion=null});
Reject("company required",student with {CompanyId=null});
Reject("company user id rejected",student with {UserId=1});
Reject("guardian id rejected",student with {GuardianId=2});
Reject("support identity rejected",student with {LaooUserId=1});
Reject("partner identity rejected",student with {PartnerUserId=1});
Reject("person identity rejected",student with {PersonId=1});
Reject("impersonation capability rejected",student with {CanLoginAsUser=true});
Reject("wrong login mode rejected",student with {LoginMode="COMPANY"});
Reject("wrong project rejected",student with {ProjectCode="LAOO"});
Reject("student claims on company user rejected",baseline with {StudentId=3,CredentialVersion=1});
Console.WriteLine($"Passed {count} isolated token contract checks. No database or production signing key used.");
