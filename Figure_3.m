%Asset value
%
%Created Aug 14 2024
%by Robert Fofrich Navarro
%
%Calculates corporate asset value and assigns values to power plant parent company
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
FUEL = 1;% sets fuel %1 COAL,2 GAS, 3 OIL, 4 Combined
clearvars -except ii; close all

TJ_to_BTu = 1/(9.478*1e8);
Kg_CO2_to_t_C02 = 1/1000;
BTu_perKWh_to_BTu_perMWh = 1000;

max_marker_size = 3000;
min_marker_size = 200; 


PowerPlantFuel = ["Coal", "Gas", "Oil"];
saveyear = 0;%saves decommission year; any other number loads decommission year
saveresults = 1;
randomsave = 1;%set to 1 to save MC randomization; zero value  loads MC randomization - section 11 only


if FUEL <4
CombineFuelTypeResults = 0;
elseif FUEL >3
CombineFuelTypeResults = 1;
end

current_year = 2024;
cutoffyear = 2035;%follows the index for carbontaxyear vector
CarbonPrice = 2000;%$/tCO2
CarbonTaxYear = current_year:2100;%sets the year for which the carbon tax is at its maximum

[ Dateindx] = find(CarbonTaxYear == cutoffyear);

StartYear = 1900;
EndYear = current_year;
Year = StartYear:EndYear;

RetailtoWholesaleConversionFactor = 1;%assumption

%Median PowerPlant Costs and Life from IPCC AR5 WGIII
%(https://www.ipcc.ch/site/assets/uploads/2018/02/ipcc_wg3_ar5_annex-iii.pdf)
%Power plant life

interest_rate_construction = .05; % interest rate over the construction loan (set as 5%)
DiscountRate = .1; %rate used by IEA 2020 report, 7% is in a highly regulated market, and 10% is in an environment with high risks

mean_Life_coal = 40;
Variable_OM_coal = 3.4;% $/MWh
Fixed_OM_coal = 23*1000;% $/MW
Construction_period_coal = 6; 
Capital_costs_coal = 2200*1000;% $/MW
Fuel_costs_coal = 4.1/3.6; % $/MWh
alpha_coal = DiscountRate/(1-(1+DiscountRate).^-mean_Life_coal);% percent
eta_coal = .39;% percent
Investment_costs_coal = (Capital_costs_coal/mean_Life_coal)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_coal)));

mean_Life_gas = 30;
Variable_OM_gas = 3.2;% $/MWh
Fixed_OM_gas = 7*1000;% $/MW
Construction_period_gas = 4; 
Capital_costs_gas = 1100*1000;% $/MW
Fuel_costs_gas = 8.9*3.6; % $/MWh
alpha_gas = DiscountRate/(1-(1+DiscountRate).^-mean_Life_gas);% percent
eta_gas = .55;% percent
Investment_costs_gas = (Capital_costs_gas/mean_Life_gas)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_gas)));

%Power plant ranges
LifeTimeRange = 20:5:60; 
CapacityFactorRange = .25:.05:.75;
AnnualHours = 8760;

%plus/minus age
Age_span = 20;% Power plant age range

%plus/minus CF
CF_span = .25;% Power plant capacity factor range
if FUEL == 1
years = 2021:(current_year + mean_Life_coal);
elseif FUEL == 2
years = 2021:(current_year + mean_Life_gas);
end

if FUEL == 1
    load '../Data/Results/PowerPlantFinances_byCompany_Coal'
    load '../Data/Results/CoalAnnualEmissions.mat'
    load '../Data/Results/colorschemecategoryCoal2'
    load ../Data/Results/CoalCompanyCapacity.mat

    RegionList = {'United States','Latin America','China','Europe',...
            'Middle East and Africa','Asia','Former Soviet','Australia, Canada, New Zealand','India'};
        
    RGB_colors = [1 0 0; 0 1 0; 0 0 1; 0 1 1; 1 0 1; 1 1 0; 0 0 0; 0 0.4470 0.7410; 0.8500 0.3250 0.0980];
        
    Company_RGB_colors = zeros(length(CoalAnnualEmissions_Company),3);

    for i = 1:length(CoalAnnualEmissions_Company)
        for j = 1:length(RegionList)
            if colorschemecategory(i) == j
                Coal_company_country_strings(i) = RegionList(j);
                Company_RGB_colors(i,:) = RGB_colors(j,:);
            end
        end
    end

    StrandedAssetsbyCompany = squeeze(PowerPlantFinances_byCompany(:,1,5));
    CommittedEmissions_Company = sum(CoalAnnualEmissions_Company,2);

    CommittedEmissions_Company(StrandedAssetsbyCompany==0) = 0;
    StrandedAssetsbyCompany(CommittedEmissions_Company==0) = 0;

    [Sorted_for_strings,String_Indx] = sort(StrandedAssetsbyCompany,"descend");
    Sorted_Company_strings = AnnualEmissionsByCompany_Coal_strings(String_Indx);

    CommittedEmissions_Company(CommittedEmissions_Company==0)=[];
    Company_RGB_colors(StrandedAssetsbyCompany==0,:)=[];
    StrandedAssetsbyCompany(StrandedAssetsbyCompany==0)=[];

    CDF_Share_Company_Emissions = zeros(length(CommittedEmissions_Company),1);

    [Sorted_SA,Indx] = sort(StrandedAssetsbyCompany,"descend");
    Sorted_Emissions = CommittedEmissions_Company(Indx);
    Company_RGB_colors = Company_RGB_colors(Indx,:);

    for i = 1:length(CDF_Share_Company_Emissions)
        if i==1
            CDF_Share_Company_Emissions(i,1) = Sorted_Emissions(i,1);
        else
            CDF_Share_Company_Emissions(i,1) = Sorted_Emissions(i,1) + CDF_Share_Company_Emissions(i-1,1);
        end
    end
    
    edges = zeros(length(CDF_Share_Company_Emissions)+1,1);
    edges(2:end,1) = CDF_Share_Company_Emissions;
    vals = Sorted_SA;

    center = (edges(1:end-1) + edges(2:end))/2;
    width = diff(edges);

    figure()
    hold on
    for i=1:length(center)
        bar(center(i),vals(i),width(i),'FaceColor', Company_RGB_colors(i,:))
    end
    hold off
    set(gca,'yscale','log')
    ylim([0 1e12])
    cx = gca;
    exportgraphics(cx,['../Plots/Coal_CDF.eps'],'ContentType','vector');   

elseif FUEL == 2

    load '../Data/Results/PowerPlantFinances_byCompany_Gas'
    load '../Data/Results/GasAnnualEmissions.mat'
    load '../Data/Results/colorschemecategoryGas2'
    load ../Data/Results/GasCompanyCapacity.mat

    RegionList = {'United States','Latin America','China','Europe',...
            'Middle East and Africa','Asia','Former Soviet','Australia, Canada, New Zealand','India'};
        
    RGB_colors = [1 0 0; 0 1 0; 0 0 1; 0 1 1; 1 0 1; 1 1 0; 0 0 0; 0 0.4470 0.7410; 0.8500 0.3250 0.0980];
        

    Company_RGB_colors = zeros(length(GasAnnualEmissions_Company),3);

    for i = 1:length(GasAnnualEmissions_Company)
        for j = 1:length(RegionList)
            if colorschemecategory(i) == j
                Gas_company_country_strings(i) = RegionList(j);
                Company_RGB_colors(i,:) = RGB_colors(j,:);
            end
        end
    end

    StrandedAssetsbyCompany = squeeze(PowerPlantFinances_byCompany(:,1,5));
    CommittedEmissions_Company = sum(GasAnnualEmissions_Company,2);
    NPV_CT = PowerPlantFinances_byCompany(:,1,4);
    Installed_Capacity = AnnualCapacityByCompany(:,1);
    Company_RGB_colors_NPV = Company_RGB_colors;

    NPV_CT(Installed_Capacity==0)=0;
    Installed_Capacity(NPV_CT==0)=0;

    [Sorted_for_strings_NPV,String_Indx_NPV] = sort(NPV_CT,"descend");
    Sorted_Company_strings_NPV = AnnualEmissionsByCompany_Gas_strings(String_Indx_NPV);

    Company_RGB_colors_NPV(NPV_CT==0,:)=[];
    NPV_CT(NPV_CT==0)=[]; Installed_Capacity(Installed_Capacity==0)=[];

    CommittedEmissions_Company(StrandedAssetsbyCompany==0) = 0;
    StrandedAssetsbyCompany(CommittedEmissions_Company==0) = 0;

    [Sorted_for_strings,String_Indx] = sort(StrandedAssetsbyCompany,"descend");
    Sorted_Company_strings = AnnualEmissionsByCompany_Gas_strings(String_Indx);

    CommittedEmissions_Company(CommittedEmissions_Company==0)=[];
    Company_RGB_colors(StrandedAssetsbyCompany==0,:)=[];
    StrandedAssetsbyCompany(StrandedAssetsbyCompany==0)=[];

    CDF_Share_Company_Emissions = zeros(length(CommittedEmissions_Company),1);
    CDF_Share_Company_Capacity = zeros(length(Installed_Capacity),1);

    [Sorted_SA,Indx] = sort(StrandedAssetsbyCompany,"descend");
    Sorted_Emissions = CommittedEmissions_Company(Indx);
    Company_RGB_colors = Company_RGB_colors(Indx,:);


    [Sorted_NPV,Indx] = sort(NPV_CT,"descend");
    Sorted_Installed_Capacity = Installed_Capacity(Indx);
    Company_RGB_colors_NPV = Company_RGB_colors_NPV(Indx,:);

    for i = 1:length(CDF_Share_Company_Capacity)
        if i==1
            CDF_Share_Company_Capacity(i,1) = Sorted_Installed_Capacity(i,1);
        else
            CDF_Share_Company_Capacity(i,1) = Sorted_Installed_Capacity(i,1) + CDF_Share_Company_Capacity(i-1,1);
        end
    end


    for i = 1:length(CDF_Share_Company_Emissions)
        if i==1
            CDF_Share_Company_Emissions(i,1) = Sorted_Emissions(i,1);
        else
            CDF_Share_Company_Emissions(i,1) = Sorted_Emissions(i,1) + CDF_Share_Company_Emissions(i-1,1);
        end
    end
    
    edges = zeros(length(CDF_Share_Company_Emissions)+1,1);
    edges(2:end,1) = CDF_Share_Company_Emissions;
    vals = Sorted_SA;

    edges_NPV = zeros(length(CDF_Share_Company_Capacity)+1,1);
    edges_NPV(2:end,1) = CDF_Share_Company_Capacity;
    vals_NPV = Sorted_NPV;


    center = (edges(1:end-1) + edges(2:end))/2;
    width = diff(edges);

    center_NPV = (edges_NPV(1:end-1) + edges_NPV(2:end))/2;
    width_NPV = diff(edges_NPV);

    figure()
    hold on
    for i=1:length(center)
        bar(center(i),vals(i),width(i),'FaceColor', Company_RGB_colors(i,:))
    end
    hold off
    set(gca,'yscale','log')
    ylim([0 1e12])
    cx = gca;
    exportgraphics(cx,['../Plots/Gas_CDF.eps'],'ContentType','vector');   
end
